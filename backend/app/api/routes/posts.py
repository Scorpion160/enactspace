from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.database import get_db
from app.models.post import Post, PostComment, PostReaction
from app.models.user import User
from app.schemas.post import (
    PostCreate,
    PostUpdate,
    PostRead,
    PostCommentCreate,
    PostCommentRead,
    PostReactionCreate,
    PostReactionRead,
    PostStatsRead,
)
from app.api.deps import (
    get_current_active_validated_user,
    require_enacchef_or_admin,
)

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


def get_post_or_404(db: Session, post_id: str) -> Post:
    post = db.query(Post).filter(Post.id == post_id).first()

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Publication introuvable",
        )

    return post


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
    query = db.query(Post)

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
    return db.query(Post).filter(
        Post.is_official == True
    ).order_by(Post.created_at.desc()).all()


@router.get("/feed", response_model=list[PostRead])
def get_main_feed(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return db.query(Post).filter(
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
    return get_post_or_404(db, post_id)


@router.patch("/{post_id}", response_model=PostRead)
def update_post(
    post_id: str,
    payload: PostUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    post = get_post_or_404(db, post_id)

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
        post.visibility = payload.visibility

    if payload.title is not None:
        post.title = payload.title

    if payload.content is not None:
        post.content = payload.content

    if payload.is_official is not None:
        post.is_official = payload.is_official

    if payload.is_pinned is not None:
        post.is_pinned = payload.is_pinned

    post.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(post)

    return post


@router.post("/{post_id}/pin", response_model=PostRead)
def pin_post(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    post = get_post_or_404(db, post_id)

    post.is_pinned = True
    post.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(post)

    return post


@router.post("/{post_id}/unpin", response_model=PostRead)
def unpin_post(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    post = get_post_or_404(db, post_id)

    post.is_pinned = False
    post.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(post)

    return post


@router.delete("/{post_id}")
def delete_post(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    post = get_post_or_404(db, post_id)

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
    get_post_or_404(db, str(payload.post_id))

    comment = PostComment(
        post_id=payload.post_id,
        user_id=current_user.id,
        content=payload.content,
    )

    db.add(comment)
    db.commit()
    db.refresh(comment)

    return comment


@router.get("/{post_id}/comments", response_model=list[PostCommentRead])
def list_post_comments(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    get_post_or_404(db, post_id)

    return db.query(PostComment).filter(
        PostComment.post_id == post_id
    ).order_by(PostComment.created_at.asc()).all()


@router.delete("/comments/{comment_id}")
def delete_post_comment(
    comment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    comment = db.query(PostComment).filter(
        PostComment.id == comment_id
    ).first()

    if not comment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Commentaire introuvable",
        )

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

    get_post_or_404(db, str(payload.post_id))

    existing = db.query(PostReaction).filter(
        PostReaction.post_id == payload.post_id,
        PostReaction.user_id == current_user.id,
        PostReaction.reaction_type == payload.reaction_type,
    ).first()

    if existing:
        return existing

    reaction = PostReaction(
        post_id=payload.post_id,
        user_id=current_user.id,
        reaction_type=payload.reaction_type,
    )

    db.add(reaction)
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
    get_post_or_404(db, post_id)

    return db.query(PostReaction).filter(
        PostReaction.post_id == post_id
    ).order_by(PostReaction.created_at.asc()).all()


@router.get("/{post_id}/stats", response_model=PostStatsRead)
def get_post_stats(
    post_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    get_post_or_404(db, post_id)

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