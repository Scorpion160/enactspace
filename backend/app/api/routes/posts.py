import re
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_, func, or_

from app.db.database import get_db
from app.models.post import Post, PostComment, PostReaction
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.stored_file import StoredFile
from app.models.user import User
from app.schemas.post import (
    PostCreate,
    PostUpdate,
    PostRead,
    PostUploadCreate,
    PostUploadRead,
    PostCommentCreate,
    PostCommentRead,
    PostReactionCreate,
    PostReactionRead,
    PostStatsRead,
)
from app.api.deps import (
    get_current_active_validated_user,
    get_user_role_names,
    require_enacchef_or_admin,
)
from app.services.notification_service import notify_user, notify_users
from app.services.file_storage_service import store_base64

router = APIRouter(prefix="/posts", tags=["Publications"])


VALID_POST_TYPES = {
    "general",
    "announcement",
    "pole",
    "project",
    "event",
    "document",
    "opportunity",
    "formation",
    "alumni",
}

VALID_POST_VISIBILITIES = {
    "public_club",
    "internal",
    "pole_only",
    "project_only",
    "enacchef_only",
    "alumni_only",
    "private",
}

VALID_REACTION_TYPES = {
    "like",
    "bravo",
    "important",
    "idee",
    "merci",
    "soutien",
}

MENTION_PATTERN = re.compile(r"@([A-Za-z0-9_.-]{2,80})")

GLOBAL_POST_ROLES = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
    "financier",
    "faculty_advisor",
}

ENACCHEF_ROLES = GLOBAL_POST_ROLES | {
    "chef_pole",
    "adjoint_chef_pole",
    "chef_projet",
    "adjoint_chef_projet",
}

GLOBAL_PIN_ROLES = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
}


def mention_key(value: str | None) -> str:
    return re.sub(r"[^a-z0-9]", "", (value or "").lower())


def find_mentioned_users(db: Session, text: str | None) -> list[User]:
    keys = {
        mention_key(match)
        for match in MENTION_PATTERN.findall(text or "")
        if mention_key(match)
    }
    if not keys:
        return []

    users = db.query(User).filter(User.is_active.is_(True)).all()
    mentioned = []
    for user in users:
        first = user.first_name or ""
        last = user.last_name or ""
        email_prefix = (user.email or "").split("@", 1)[0]
        aliases = {
            mention_key(first),
            mention_key(last),
            mention_key(f"{first}{last}"),
            mention_key(f"{last}{first}"),
            mention_key(email_prefix),
        }
        if keys.intersection(aliases):
            mentioned.append(user)

    return mentioned


def notify_mentions(
    db: Session,
    *,
    current_user: User,
    text: str,
    post: Post,
    source: str,
    exclude_user_ids: set | None = None,
) -> None:
    excluded = {current_user.id, *(exclude_user_ids or set())}
    mentioned_user_ids = [
        user.id
        for user in find_mentioned_users(db, text)
        if user.id not in excluded
    ]
    if not mentioned_user_ids:
        return

    author_name = f"{current_user.first_name} {current_user.last_name}".strip()
    notify_users(
        db,
        user_ids=mentioned_user_ids,
        title=f"{author_name or 'Un membre'} vous a mentionne",
        message=(text or "")[:180],
        notification_type="post_mention",
        related_type="post",
        related_id=post.id,
    )


def post_audience_user_ids(
    db: Session,
    post: Post,
    *,
    exclude_user_ids: set | None = None,
) -> list:
    excluded = exclude_user_ids or set()
    users = db.query(User).filter(
        User.is_active.is_(True),
        User.status.in_(["active", "alumni"]),
    ).all()

    audience_ids = []
    for user in users:
        if user.id in excluded:
            continue
        can_see_post = visible_posts_query(db, user).filter(Post.id == post.id).first()
        if can_see_post:
            audience_ids.append(user.id)

    return audience_ids


def notify_post_audience(
    db: Session,
    *,
    post: Post,
    current_user: User,
    title: str,
    message: str,
    notification_type: str,
) -> None:
    audience_ids = post_audience_user_ids(
        db,
        post,
        exclude_user_ids={current_user.id},
    )
    if not audience_ids:
        return

    notify_users(
        db,
        user_ids=audience_ids,
        title=title,
        message=message[:180],
        notification_type=notification_type,
        related_type="post",
        related_id=post.id,
        dedupe=True,
    )


def user_scope_ids(db: Session, current_user: User) -> tuple[set, set]:
    pole_ids = {
        row[0]
        for row in db.query(PoleMember.pole_id)
        .filter(
            PoleMember.user_id == current_user.id,
            PoleMember.is_active.is_(True),
            PoleMember.left_at.is_(None),
        )
        .all()
    }
    project_ids = {
        row[0]
        for row in db.query(ProjectMember.project_id)
        .filter(
            ProjectMember.user_id == current_user.id,
            ProjectMember.is_active.is_(True),
            ProjectMember.left_at.is_(None),
        )
        .all()
    }
    return pole_ids, project_ids


def visible_posts_query(db: Session, current_user: User):
    roles = get_user_role_names(db, current_user.id)
    pole_ids, project_ids = user_scope_ids(db, current_user)

    if roles.intersection(GLOBAL_POST_ROLES):
        return db.query(Post).filter(
            or_(
                Post.visibility != "private",
                Post.author_id == current_user.id,
            )
        )

    conditions = [
        Post.visibility.in_(("public_club", "internal")),
        Post.author_id == current_user.id,
    ]
    if current_user.status == "alumni" or "alumni" in roles:
        conditions.append(Post.visibility == "alumni_only")
    if roles.intersection(ENACCHEF_ROLES):
        conditions.append(Post.visibility == "enacchef_only")
    if pole_ids:
        conditions.append(
            and_(
                Post.visibility == "pole_only",
                Post.pole_id.in_(pole_ids),
            )
        )
    if project_ids:
        conditions.append(
            and_(
                Post.visibility == "project_only",
                Post.project_id.in_(project_ids),
            )
        )

    return db.query(Post).filter(or_(*conditions))


def get_visible_post_or_404(
    db: Session,
    post_id: str,
    current_user: User,
) -> Post:
    post = visible_posts_query(db, current_user).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Publication introuvable ou non accessible",
        )
    return post


def ensure_post_scope_allowed(
    db: Session,
    current_user: User,
    *,
    visibility: str,
    pole_id=None,
    project_id=None,
) -> None:
    roles = get_user_role_names(db, current_user.id)
    if roles.intersection(GLOBAL_POST_ROLES):
        return

    pole_ids, project_ids = user_scope_ids(db, current_user)
    if visibility == "enacchef_only" and not roles.intersection(ENACCHEF_ROLES):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Publication réservée aux membres d'Enacchef",
        )
    if visibility == "alumni_only" and not (
        current_user.status == "alumni" or "alumni" in roles
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Publication réservée aux alumni",
        )
    if visibility == "pole_only" and pole_id not in pole_ids:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Sélectionnez un pôle auquel vous appartenez",
        )
    if visibility == "project_only" and project_id not in project_ids:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Sélectionnez un projet auquel vous appartenez",
        )

def ensure_can_moderate_post(
    db: Session,
    current_user: User,
    post: Post,
) -> None:
    roles = get_user_role_names(db, current_user.id)
    if roles.intersection(GLOBAL_POST_ROLES) or post.author_id == current_user.id:
        return

    pole_ids, project_ids = user_scope_ids(db, current_user)
    if (
        post.pole_id in pole_ids
        and roles.intersection({"chef_pole", "adjoint_chef_pole"})
    ):
        return
    if (
        post.project_id in project_ids
        and roles.intersection({"chef_projet", "adjoint_chef_projet"})
    ):
        return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Vous ne pouvez pas modérer cette publication",
    )


def ensure_can_pin_post(
    db: Session,
    current_user: User,
    post: Post,
) -> None:
    roles = get_user_role_names(db, current_user.id)
    if roles.intersection(GLOBAL_PIN_ROLES):
        return

    pole_ids, project_ids = user_scope_ids(db, current_user)
    if (
        post.pole_id in pole_ids
        and roles.intersection({"chef_pole", "adjoint_chef_pole"})
    ):
        return
    if (
        post.project_id in project_ids
        and roles.intersection({"chef_projet", "adjoint_chef_projet"})
    ):
        return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Seuls les responsables autorisÃ©s peuvent Ã©pingler une publication",
    )

def attach_media_to_post(
    db: Session,
    *,
    file_id,
    post: Post,
    current_user: User,
) -> StoredFile | None:
    if not file_id:
        return None

    stored_file = db.query(StoredFile).filter(StoredFile.id == file_id).first()
    if not stored_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Media de publication introuvable",
        )
    if stored_file.uploaded_by_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez pas utiliser ce media.",
        )

    stored_file.storage_scope = "post"
    stored_file.visibility = post.visibility
    stored_file.entity_type = "post"
    stored_file.entity_id = post.id
    stored_file.is_temporary = False
    stored_file.is_ephemeral = False
    stored_file.expires_at = None
    stored_file.updated_at = datetime.utcnow()

    post.media_file_id = stored_file.id
    post.media_url = f"/api/files/{stored_file.id}/preview"
    post.media_name = stored_file.original_filename
    post.media_mime_type = stored_file.mime_type
    post.media_size_bytes = stored_file.file_size
    return stored_file


@router.post("/uploads", response_model=PostUploadRead)
def upload_post_media(
    payload: PostUploadCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    stored_file = store_base64(
        db,
        data_base64=payload.data_base64,
        original_filename=payload.file_name,
        uploaded_by=current_user,
        mime_type=payload.content_type,
        storage_scope="post",
        visibility="private",
        is_temporary=True,
    )
    db.commit()
    db.refresh(stored_file)

    return PostUploadRead(
        file_id=stored_file.id,
        url=f"/api/files/{stored_file.id}/preview",
        file_name=stored_file.original_filename,
        content_type=stored_file.mime_type,
        size_bytes=stored_file.file_size,
    )


@router.post("/", response_model=PostRead)
def create_post(
    payload: PostCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    if payload.post_type not in VALID_POST_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de publication invalide",
        )

    if payload.visibility not in VALID_POST_VISIBILITIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Visibilité invalide",
        )

    ensure_post_scope_allowed(
        db,
        current_user,
        visibility=payload.visibility,
        pole_id=payload.pole_id,
        project_id=payload.project_id,
    )

    if payload.is_official or payload.post_type == "announcement":
        from app.api.deps import user_has_any_role

        allowed_roles = {
            "team_leader",
            "secretaire_generale",
            "chef_pole",
            "adjoint_chef_pole",
            "chef_projet",
            "adjoint_chef_projet",
            "administrateur",
            "faculty_advisor",
        }

        if not user_has_any_role(db, current_user.id, allowed_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Seuls les responsables peuvent publier une annonce officielle",
            )

    post = Post(
        author_id=current_user.id,
        title=payload.title,
        content=payload.content,
        post_type=payload.post_type,
        pole_id=payload.pole_id,
        project_id=payload.project_id,
        event_id=payload.event_id,
        document_id=payload.document_id,
        is_official=payload.is_official,
        visibility=payload.visibility,
    )

    db.add(post)
    db.flush()
    attach_media_to_post(
        db,
        file_id=payload.media_file_id,
        post=post,
        current_user=current_user,
    )
    notify_mentions(
        db,
        current_user=current_user,
        text=f"{payload.title or ''} {payload.content}",
        post=post,
        source="post",
    )
    if post.is_official or post.post_type == "announcement":
        notify_post_audience(
            db,
            post=post,
            current_user=current_user,
            title="Nouvelle publication officielle",
            message=post.title or post.content,
            notification_type="official_post",
        )
    db.commit()
    db.refresh(post)

    return post


@router.get("/", response_model=list[PostRead])
def list_posts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    search: str | None = Query(default=None),
    post_type: str | None = Query(default=None),
    visibility: str | None = Query(default=None),
    pole_id: str | None = Query(default=None),
    project_id: str | None = Query(default=None),
    event_id: str | None = Query(default=None),
    is_official: bool | None = Query(default=None),
    is_pinned: bool | None = Query(default=None),
):
    query = visible_posts_query(db, current_user)

    if search:
        pattern = f"%{search}%"
        query = query.filter(
            (Post.title.ilike(pattern)) |
            (Post.content.ilike(pattern))
        )

    if post_type:
        query = query.filter(Post.post_type == post_type)

    if visibility:
        query = query.filter(Post.visibility == visibility)

    if pole_id:
        query = query.filter(Post.pole_id == pole_id)

    if project_id:
        query = query.filter(Post.project_id == project_id)

    if event_id:
        query = query.filter(Post.event_id == event_id)

    if is_official is not None:
        query = query.filter(Post.is_official == is_official)

    if is_pinned is not None:
        query = query.filter(Post.is_pinned == is_pinned)

    return query.order_by(
        Post.is_pinned.desc(),
        Post.created_at.desc(),
    ).all()


@router.get("/official", response_model=list[PostRead])
def list_official_posts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return visible_posts_query(db, current_user).filter(
        Post.is_official.is_(True)
    ).order_by(Post.created_at.desc()).all()


@router.get("/feed", response_model=list[PostRead])
def get_main_feed(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return visible_posts_query(db, current_user).filter(
        Post.visibility.in_(["public_club", "internal"])
    ).order_by(
        Post.is_pinned.desc(),
        Post.created_at.desc(),
    ).all()


@router.get("/{post_id}", response_model=PostRead)
def get_post(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return get_visible_post_or_404(db, post_id, current_user)


@router.patch("/{post_id}", response_model=PostRead)
def update_post(
    post_id: str,
    payload: PostUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    post = get_visible_post_or_404(db, post_id, current_user)
    ensure_can_moderate_post(db, current_user, post)
    current_roles = get_user_role_names(db, current_user.id)
    was_official = post.is_official
    was_pinned = post.is_pinned

    if payload.post_type is not None:
        if payload.post_type not in VALID_POST_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Type de publication invalide",
            )
        post.post_type = payload.post_type

    if payload.visibility is not None:
        if payload.visibility not in VALID_POST_VISIBILITIES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Visibilité invalide",
            )
        ensure_post_scope_allowed(
            db,
            current_user,
            visibility=payload.visibility,
            pole_id=post.pole_id,
            project_id=post.project_id,
        )
        post.visibility = payload.visibility
        if post.media_file_id:
            stored_file = db.query(StoredFile).filter(
                StoredFile.id == post.media_file_id
            ).first()
            if stored_file:
                stored_file.visibility = post.visibility
                stored_file.updated_at = datetime.utcnow()

    if payload.title is not None:
        post.title = payload.title

    if payload.content is not None:
        post.content = payload.content

    if payload.media_file_id is not None:
        attach_media_to_post(
            db,
            file_id=payload.media_file_id,
            post=post,
            current_user=current_user,
        )

    if payload.is_official is not None:
        if not current_roles.intersection(ENACCHEF_ROLES):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Seuls les responsables peuvent publier officiellement",
            )
        post.is_official = payload.is_official

    if payload.is_pinned is not None:
        ensure_can_pin_post(db, current_user, post)
        post.is_pinned = payload.is_pinned

    post.updated_at = datetime.utcnow()
    db.flush()
    if post.is_official and not was_official:
        notify_post_audience(
            db,
            post=post,
            current_user=current_user,
            title="Publication marquee officielle",
            message=post.title or post.content,
            notification_type="official_post",
        )
    if post.is_pinned and not was_pinned:
        notify_post_audience(
            db,
            post=post,
            current_user=current_user,
            title="Publication epinglee",
            message=post.title or post.content,
            notification_type="post_pinned",
        )

    db.commit()
    db.refresh(post)

    return post


@router.post("/{post_id}/pin", response_model=PostRead)
def pin_post(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    post = get_visible_post_or_404(db, post_id, current_user)
    ensure_can_pin_post(db, current_user, post)
    was_pinned = post.is_pinned

    post.is_pinned = True
    post.updated_at = datetime.utcnow()
    db.flush()
    if not was_pinned:
        notify_post_audience(
            db,
            post=post,
            current_user=current_user,
            title="Publication epinglee",
            message=post.title or post.content,
            notification_type="post_pinned",
        )

    db.commit()
    db.refresh(post)

    return post


@router.post("/{post_id}/unpin", response_model=PostRead)
def unpin_post(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    post = get_visible_post_or_404(db, post_id, current_user)
    ensure_can_pin_post(db, current_user, post)

    post.is_pinned = False
    post.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(post)

    return post


@router.delete("/{post_id}")
def delete_post(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    post = get_visible_post_or_404(db, post_id, current_user)
    ensure_can_moderate_post(db, current_user, post)

    db.delete(post)
    db.commit()

    return {
        "ok": True,
        "message": "Publication supprimée",
    }


@router.post("/comments", response_model=PostCommentRead)
def create_post_comment(
    payload: PostCommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    post = get_visible_post_or_404(db, str(payload.post_id), current_user)
    content = payload.content.strip()
    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le commentaire ne peut pas être vide",
        )

    comment = PostComment(
        post_id=payload.post_id,
        user_id=current_user.id,
        content=content,
    )

    db.add(comment)
    if post.author_id != current_user.id:
        commenter_name = (
            f"{current_user.first_name} {current_user.last_name}".strip()
        )
        notify_user(
            db,
            user_id=post.author_id,
            title=f"Nouveau commentaire de {commenter_name}",
            message=content[:180],
            notification_type="post_comment",
            related_type="post",
            related_id=post.id,
        )
    notify_mentions(
        db,
        current_user=current_user,
        text=content,
        post=post,
        source="comment",
        exclude_user_ids={post.author_id},
    )
    db.commit()
    db.refresh(comment)

    return comment


@router.get("/{post_id}/comments", response_model=list[PostCommentRead])
def list_post_comments(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    get_visible_post_or_404(db, post_id, current_user)

    return db.query(PostComment).filter(
        PostComment.post_id == post_id
    ).order_by(PostComment.created_at.asc()).all()


@router.delete("/comments/{comment_id}")
def delete_post_comment(
    comment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    comment = db.query(PostComment).filter(
        PostComment.id == comment_id
    ).first()

    if not comment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Commentaire introuvable",
        )

    post = get_visible_post_or_404(db, str(comment.post_id), current_user)
    if comment.user_id != current_user.id:
        ensure_can_moderate_post(db, current_user, post)
    db.delete(comment)
    db.commit()

    return {
        "ok": True,
        "message": "Commentaire supprimé",
    }


@router.post("/reactions", response_model=PostReactionRead)
def create_post_reaction(
    payload: PostReactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    if payload.reaction_type not in VALID_REACTION_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de réaction invalide",
        )

    post = get_visible_post_or_404(db, str(payload.post_id), current_user)

    existing_reactions = db.query(PostReaction).filter(
        PostReaction.post_id == payload.post_id,
        PostReaction.user_id == current_user.id,
    ).order_by(PostReaction.created_at.asc()).all()

    if existing_reactions:
        reaction = existing_reactions[0]
        reaction.reaction_type = payload.reaction_type
        for duplicate in existing_reactions[1:]:
            db.delete(duplicate)
        db.commit()
        db.refresh(reaction)
        return reaction

    reaction = PostReaction(
        post_id=payload.post_id,
        user_id=current_user.id,
        reaction_type=payload.reaction_type,
    )

    db.add(reaction)
    if post.author_id != current_user.id:
        reactor_name = f"{current_user.first_name} {current_user.last_name}".strip()
        notify_user(
            db,
            user_id=post.author_id,
            title=f"{reactor_name} a réagi à votre publication",
            message=f"Réaction : {payload.reaction_type}",
            notification_type="post_reaction",
            related_type="post",
            related_id=post.id,
        )
    db.commit()
    db.refresh(reaction)

    return reaction


@router.delete("/reactions/{reaction_id}")
def delete_post_reaction(
    reaction_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    reaction = db.query(PostReaction).filter(
        PostReaction.id == reaction_id
    ).first()

    if not reaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Réaction introuvable",
        )

    if reaction.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez retirer que votre propre réaction",
        )
    get_visible_post_or_404(db, str(reaction.post_id), current_user)
    db.delete(reaction)
    db.commit()

    return {
        "ok": True,
        "message": "Réaction supprimée",
    }


@router.get("/{post_id}/reactions", response_model=list[PostReactionRead])
def list_post_reactions(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    get_visible_post_or_404(db, post_id, current_user)

    return db.query(PostReaction).filter(
        PostReaction.post_id == post_id
    ).order_by(PostReaction.created_at.asc()).all()


@router.get("/{post_id}/stats", response_model=PostStatsRead)
def get_post_stats(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    get_visible_post_or_404(db, post_id, current_user)

    comments_count = db.query(func.count(PostComment.id)).filter(
        PostComment.post_id == post_id
    ).scalar() or 0

    reactions_count = db.query(func.count(PostReaction.id)).filter(
        PostReaction.post_id == post_id
    ).scalar() or 0

    return PostStatsRead(
        post_id=post_id,
        comments_count=comments_count,
        reactions_count=reactions_count,
    )
