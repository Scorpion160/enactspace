"""Cross-device club games. Poll room state; secrets never leave their owner."""
import secrets
import uuid
from collections import Counter

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user
from app.db.database import get_db
from app.models.games import GamePlayer, GameResponse, GameRoom
from app.models.gamification import Badge, UserBadge
from app.models.user import User
from app.services.game_content import ICEBREAKERS, QUIZ, UNDERCOVER, choose, choose_quiz

router = APIRouter(prefix="/games", tags=["Jeux du club"])
GAMES = {"quiz", "undercover", "icebreaker", "werewolf"}
MIN_PLAYERS = {"quiz": 1, "undercover": 3, "icebreaker": 1, "werewolf": 4}


class CreateRoom(BaseModel):
    game: str
    mode: str = "individual"
    theme: str = "mix"
    rounds: int = Field(default=5, ge=1, le=20)


class JoinRoom(BaseModel):
    code: str = Field(min_length=4, max_length=8)
    team: str | None = None


class SubmitResponse(BaseModel):
    answer: str = Field(min_length=1, max_length=150)


def room_or_404(db, room_id):
    try:
        key = uuid.UUID(room_id)
    except ValueError:
        raise HTTPException(404, "Partie introuvable")
    room = db.query(GameRoom).filter_by(id=key).with_for_update().first()
    if room is None:
        raise HTTPException(404, "Partie introuvable")
    return room


def players_for(db, room):
    return db.query(GamePlayer).filter_by(room_id=room.id).order_by(GamePlayer.id).all()


def member_or_403(db, room, user):
    player = db.query(GamePlayer).filter_by(room_id=room.id, user_id=user.id).first()
    if player is None:
        raise HTTPException(403, "Rejoignez cette partie avec son code")
    return player


def host_or_403(room, user):
    if room.host_id != user.id:
        raise HTTPException(403, "Seul l'organisateur peut faire avancer la partie")


def public_room(db, room, user):
    player = member_or_403(db, room, user)
    people = players_for(db, room)
    users = {item.id: item for item in db.query(User).filter(
        User.id.in_([person.user_id for person in people])).all()}
    state = room.state or {}
    prompt = state.get("prompt")
    # Never return a correct answer, civilian word or unrevealed role.
    return {
        "id": str(room.id), "code": room.code, "game": room.game,
        "theme": room.theme, "mode": room.mode, "status": room.status,
        "round": room.round_number, "rounds": room.max_rounds,
        "phase": state.get("phase", "lobby"),
        "prompt": prompt, "my_role": player.role,
        "my_secret": player.secret, "my_team": player.team,
        "host": room.host_id == user.id,
        "my_id": str(user.id),
        "lovers": state.get("lovers") if player.role == "cupid" or
            str(user.id) in state.get("lovers", []) or room.status == "finished" else None,
        "players": [{
            "id": str(person.user_id),
            "name": f"{users[person.user_id].first_name} {users[person.user_id].last_name}",
            "team": person.team,
            "score": person.score,
            "eliminated": person.eliminated,
            "role": person.role if room.status == "finished" else None,
        } for person in people],
        "my_won": player.won,
        "answered": db.query(GameResponse).filter_by(
            room_id=room.id, round_number=room.round_number, user_id=user.id).first() is not None,
        "responses": db.query(GameResponse).filter_by(
            room_id=room.id, round_number=room.round_number).count(),
        "shared_answers": [
            {"name": f"{users[item.user_id].first_name} {users[item.user_id].last_name}",
             "answer": item.answer}
            for item in db.query(GameResponse).filter_by(
                room_id=room.id, round_number=room.round_number).all()
        ] if room.game == "icebreaker" else [],
        "reveal": state["prompt"]["choices"][state["correct"]]
            if room.game == "quiz" and room.status == "playing"
            and db.query(GameResponse).filter_by(
                room_id=room.id, round_number=room.round_number).count() == len(people)
            else None,
        "result": state.get("result"),
    }


def next_prompt(room):
    state = dict(room.state or {})
    used = list(state.get("used", []))
    if room.game == "quiz":
        theme, question, choices, answer = choose_quiz(room.theme, used)
        state["prompt"] = {"question": question, "choices": choices, "theme": theme}
        state["correct"] = answer
        state["phase"] = "question"
    elif room.game == "undercover":
        civil, spy = choose(UNDERCOVER, room.theme, used)
        state["pair"] = [civil, spy]
        state["prompt"] = {"question": "Décrivez votre mot sans le prononcer, puis votez pour un suspect."}
        state["phase"] = "discussion"
    elif room.game == "icebreaker":
        prompt = choose(ICEBREAKERS, room.theme, used)
        state["prompt"] = {"question": prompt}
        state["phase"] = "question"
    state["used"] = used
    state.pop("result", None)
    room.state = state


def finish_room(db, room, winners=None):
    room.status = "finished"
    state = dict(room.state or {})
    state["phase"] = "finished"
    state["result"] = state.get("result") or "Partie terminée"
    room.state = state
    people = players_for(db, room)
    if winners is None:
        if room.game == "icebreaker" or not people:
            winners = []
        elif room.mode == "team":
            sums = Counter()
            for person in people:
                sums[person.team or ""] += person.score
            top = max(sums.values())
            winners = [person for person in people if sums[person.team or ""] == top and top > 0]
        else:
            top = max(person.score for person in people)
            winners = [person for person in people if person.score == top and top > 0]
    if room.game == "quiz" and len(people) == 1:
        # A solo practice attempt is scored, but has no competitive winner.
        winners = []
    for winner in winners:
        winner.won = True
    if winners:
        badge_name = f"champion_{room.game}"
        badge = db.query(Badge).filter_by(name=badge_name).first()
        if badge is None:
            badge = Badge(name=badge_name, label=f"Champion {room.game}",
                          description="Victoire lors d'une partie du club.")
            db.add(badge)
            db.flush()
        for winner in winners:
            if db.query(UserBadge).filter_by(user_id=winner.user_id, badge_id=badge.id).first() is None:
                db.add(UserBadge(user_id=winner.user_id, badge_id=badge.id,
                                 awarded_by=room.host_id))
    return winners


@router.post("/rooms")
def create_room(payload: CreateRoom, db: Session = Depends(get_db),
                user: User = Depends(get_current_active_validated_user)):
    if payload.game not in GAMES:
        raise HTTPException(400, "Jeu inconnu")
    if payload.mode not in ("individual", "team"):
        raise HTTPException(400, "Mode inconnu")
    themes = set(UNDERCOVER if payload.game == "undercover" else
                 ICEBREAKERS if payload.game == "icebreaker" else
                 {item[0] for item in QUIZ} if payload.game == "quiz" else [])
    if payload.theme != "mix" and payload.theme not in themes:
        raise HTTPException(400, "Thème inconnu")
    if payload.game != "quiz" and payload.mode == "team":
        raise HTTPException(400, "Le mode équipe concerne le quiz")
    if payload.game == "quiz":
        available = sum(payload.theme in ("mix", item[0]) for item in QUIZ)
    elif payload.game == "undercover":
        available = sum(len(items) for key, items in UNDERCOVER.items()
                        if payload.theme in ("mix", key))
    elif payload.game == "icebreaker":
        available = sum(len(items) for key, items in ICEBREAKERS.items()
                        if payload.theme in ("mix", key))
    else:
        available = payload.rounds
    if payload.rounds > available:
        raise HTTPException(400, f"Ce thème propose {available} manches inédites maximum")
    if payload.game == "werewolf" and payload.rounds > 10:
        raise HTTPException(400, "Maximum 10 cycles pour le loup garou")
    for _ in range(6):
        code = "".join(secrets.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(6))
        if db.query(GameRoom).filter_by(code=code).first() is None:
            break
    else:
        raise HTTPException(503, "Impossible de générer un code libre")
    room = GameRoom(code=code, host_id=user.id, game=payload.game,
                    mode=payload.mode, theme=payload.theme,
                    max_rounds=payload.rounds, state={"used": []})
    db.add(room)
    db.flush()
    db.add(GamePlayer(room_id=room.id, user_id=user.id,
                      team="A" if payload.mode == "team" else None))
    db.commit()
    return public_room(db, room, user)


@router.post("/rooms/join")
def join_room(payload: JoinRoom, db: Session = Depends(get_db),
              user: User = Depends(get_current_active_validated_user)):
    room = db.query(GameRoom).filter(
        func.upper(GameRoom.code) == payload.code.strip().upper()).with_for_update().first()
    if room is None:
        raise HTTPException(404, "Code de partie introuvable")
    existing = db.query(GamePlayer).filter_by(room_id=room.id, user_id=user.id).first()
    if existing is not None:
        return public_room(db, room, user)
    if room.status != "lobby":
        raise HTTPException(409, "La partie a déjà commencé")
    if len(players_for(db, room)) >= 24:
        raise HTTPException(409, "La salle est complète")
    if room.mode == "team" and payload.team not in ("A", "B"):
        raise HTTPException(400, "Choisissez l'équipe A ou B")
    db.add(GamePlayer(room_id=room.id, user_id=user.id,
                      team=payload.team if room.mode == "team" else None))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
    return public_room(db, room, user)


@router.get("/rooms/mine")
def my_rooms(db: Session = Depends(get_db),
             user: User = Depends(get_current_active_validated_user)):
    rows = db.query(GameRoom).join(GamePlayer).filter(
        GamePlayer.user_id == user.id).order_by(GameRoom.created_at.desc()).limit(25).all()
    return [public_room(db, row, user) for row in rows]


@router.get("/rooms/{room_id}")
def get_room(room_id: str, db: Session = Depends(get_db),
             user: User = Depends(get_current_active_validated_user)):
    return public_room(db, room_or_404(db, room_id), user)


@router.post("/rooms/{room_id}/start")
def start_room(room_id: str, db: Session = Depends(get_db),
               user: User = Depends(get_current_active_validated_user)):
    room = room_or_404(db, room_id)
    host_or_403(room, user)
    if room.status != "lobby":
        raise HTTPException(409, "Partie déjà démarrée")
    people = players_for(db, room)
    if len(people) < MIN_PLAYERS[room.game]:
        raise HTTPException(400, f"Il faut {MIN_PLAYERS[room.game]} joueur(s) minimum")
    if room.mode == "team" and {p.team for p in people} != {"A", "B"}:
        raise HTTPException(400, "Chaque équipe doit compter un joueur")
    room.status = "playing"
    room.round_number = 1
    if room.game == "undercover":
        next_prompt(room)
        spy = secrets.choice(people)
        for person in people:
            person.role = "undercover" if person == spy else "civil"
            person.secret = room.state["pair"][1 if person == spy else 0]
    elif room.game == "werewolf":
        people = secrets.SystemRandom().sample(people, len(people))
        people[0].role = "wolf"
        people[1].role = "cupid"
        if len(people) >= 6:
            people[2].role = "seer"
        for person in people:
            person.role = person.role or "villager"
            person.secret = person.role
        room.state = {"phase": "cupid", "lovers": [], "prompt": {
            "question": "Cupidon désigne deux amoureux. Les autres attendent."}}
    else:
        next_prompt(room)
    db.commit()
    return public_room(db, room, user)


@router.post("/rooms/{room_id}/answer")
def answer_room(room_id: str, payload: SubmitResponse, db: Session = Depends(get_db),
                user: User = Depends(get_current_active_validated_user)):
    room = room_or_404(db, room_id)
    player = member_or_403(db, room, user)
    if room.status != "playing" or player.eliminated:
        raise HTTPException(409, "Cette manche n'accepte pas de réponse")
    if db.query(GameResponse).filter_by(
            room_id=room.id, user_id=user.id, round_number=room.round_number).first():
        raise HTTPException(409, "Réponse déjà enregistrée")
    answer = payload.answer.strip()
    state = dict(room.state or {})
    response_round = room.round_number
    if room.game == "quiz":
        if answer not in ("0", "1", "2", "3"):
            raise HTTPException(400, "Choisissez une réponse")
        if int(answer) == state["correct"]:
            player.score += 10
    elif room.game == "werewolf" and state.get("phase") == "cupid":
        if player.role != "cupid":
            raise HTTPException(403, "Seul Cupidon choisit les amoureux")
        ids = answer.split(",")
        candidates = {str(person.user_id) for person in players_for(db, room)}
        if len(ids) != 2 or ids[0] == ids[1] or not set(ids).issubset(candidates):
            raise HTTPException(400, "Choisissez deux joueurs distincts")
        state["lovers"] = ids
        state["phase"] = "night"
        state["prompt"] = {"question": "Le loup choisit une cible pendant la nuit."}
        room.state = state
        # Move to a fresh round so Cupidon may vote during the day.
        room.round_number += 1
        response_round = room.round_number - 1
    elif room.game in ("undercover", "werewolf"):
        if room.game == "werewolf" and state.get("phase") == "night" and player.role != "wolf":
            raise HTTPException(403, "Seul le loup choisit la cible la nuit")
        valid = {str(person.user_id) for person in players_for(db, room)
                 if not person.eliminated and person.user_id != user.id}
        if answer not in valid:
            raise HTTPException(400, "Choisissez un autre joueur encore en jeu")
    elif room.game == "icebreaker" and len(answer) < 2:
        raise HTTPException(400, "Réponse trop courte")
    db.add(GameResponse(room_id=room.id, user_id=user.id,
                        round_number=response_round, answer=answer))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Réponse déjà enregistrée")
    return public_room(db, room, user)


def resolve_vote(db, room, voters):
    ballots = db.query(GameResponse).filter_by(
        room_id=room.id, round_number=room.round_number).all()
    if len(ballots) < len(voters):
        raise HTTPException(409, "Attendez les votes des joueurs concernés")
    counts = Counter(ballot.answer for ballot in ballots)
    top = max(counts.values(), default=0)
    targets = [key for key, value in counts.items() if value == top]
    if len(targets) != 1:
        return None
    return next((p for p in players_for(db, room) if str(p.user_id) == targets[0]), None)


def eliminate(room, target, players):
    target.eliminated = True
    lovers = (room.state or {}).get("lovers", [])
    if str(target.user_id) in lovers:
        for partner in players:
            if str(partner.user_id) in lovers:
                partner.eliminated = True


@router.post("/rooms/{room_id}/next")
def next_round(room_id: str, db: Session = Depends(get_db),
               user: User = Depends(get_current_active_validated_user)):
    room = room_or_404(db, room_id)
    host_or_403(room, user)
    if room.status != "playing":
        raise HTTPException(409, "La partie n'est pas en cours")
    people = players_for(db, room)
    state = dict(room.state or {})
    if room.game == "quiz":
        ballots = db.query(GameResponse).filter_by(
            room_id=room.id, round_number=room.round_number).count()
        if ballots < len(people):
            raise HTTPException(409, "Attendez toutes les réponses")
        correct = state["prompt"]["choices"][state["correct"]]
        if room.round_number >= room.max_rounds:
            state["result"] = f"Dernière réponse : {correct}"
            room.state = state
            finish_room(db, room)
        else:
            room.round_number += 1
            next_prompt(room)
            state = dict(room.state)
            state["result"] = f"Réponse précédente : {correct}"
            room.state = state
    elif room.game == "icebreaker":
        if room.round_number >= room.max_rounds:
            finish_room(db, room)
        else:
            room.round_number += 1
            next_prompt(room)
    elif room.game == "undercover":
        active = [p for p in people if not p.eliminated]
        target = resolve_vote(db, room, active)
        if target:
            target.eliminated = True
        spy = next(p for p in people if p.role == "undercover")
        if spy.eliminated or len([p for p in people if not p.eliminated]) <= 2:
            winners = [p for p in people if
                       (p.role == "undercover") == (not spy.eliminated)]
            for winner in winners:
                winner.score += 10
            state["result"] = ("Les civils ont trouvé l'Undercover !" if spy.eliminated
                               else "L'Undercover a gagné !")
            room.state = state
            finish_room(db, room, winners)
        elif room.round_number >= room.max_rounds:
            winners = [spy]
            spy.score += 10
            state["result"] = "L'Undercover a résisté jusqu'à la dernière manche."
            room.state = state
            finish_room(db, room, winners)
        else:
            room.round_number += 1
            state["result"] = (f"Un joueur a été éliminé." if target else
                               "Égalité : aucun joueur éliminé.")
            state["phase"] = "discussion"
            room.state = state
    else:
        phase = state.get("phase")
        if phase == "cupid":
            raise HTTPException(409, "Cupidon doit choisir deux amoureux")
        active = [p for p in people if not p.eliminated]
        if phase == "night":
            wolf = next((p for p in active if p.role == "wolf"), None)
            if wolf is None:
                raise HTTPException(409, "Le loup n'est plus en jeu")
            target = resolve_vote(db, room, [wolf])
        else:
            target = resolve_vote(db, room, active)
        if target:
            eliminate(room, target, people)
        alive = [p for p in people if not p.eliminated]
        wolves = [p for p in alive if p.role == "wolf"]
        lovers = [p for p in alive if str(p.user_id) in state.get("lovers", [])]
        if not wolves or len(wolves) >= len(alive) - len(wolves) or len(lovers) == 2 and len(alive) == 2:
            if len(lovers) == 2 and len(alive) == 2:
                winners = lovers
                result = "Les amoureux remportent la partie !"
            elif wolves:
                winners = wolves
                result = "Le loup remporte la partie !"
            else:
                winners = [p for p in people if p.role != "wolf"]
                result = "Le village remporte la partie !"
            for winner in winners:
                winner.score += 10
            state["result"] = result
            room.state = state
            finish_room(db, room, winners)
        elif room.round_number >= room.max_rounds * 2:
            room.state = state
            finish_room(db, room, [])
        else:
            room.round_number += 1
            state["phase"] = "day" if phase == "night" else "night"
            state["prompt"] = {"question": ("Le village débat et vote." if phase == "night"
                                            else "Le loup choisit une cible pendant la nuit.")}
            state["result"] = "Une personne a été éliminée." if target else "Égalité : personne éliminée."
            room.state = state
    db.commit()
    return public_room(db, room, user)


@router.get("/leaderboard")
def leaderboard(game: str | None = Query(default=None),
                db: Session = Depends(get_db),
                user: User = Depends(get_current_active_validated_user)):
    if game is not None and game not in GAMES:
        raise HTTPException(400, "Jeu inconnu")
    rows = db.query(GamePlayer, User, GameRoom).join(
        User, User.id == GamePlayer.user_id).join(
        GameRoom, GameRoom.id == GamePlayer.room_id).filter(
        GameRoom.status == "finished").all()
    if game is not None:
        rows = [row for row in rows if row[2].game == game]
    totals = {}
    for player, member, room in rows:
        entry = totals.setdefault(str(member.id), {
            "id": str(member.id), "name": f"{member.first_name} {member.last_name}",
            "points": 0, "wins": 0, "games": 0, "best_solo": 0})
        count = db.query(GamePlayer).filter_by(room_id=room.id).count()
        if room.game == "quiz" and count == 1:
            entry["best_solo"] = max(entry["best_solo"], player.score)
        else:
            entry["points"] += player.score
            entry["wins"] += int(player.won)
        entry["games"] += 1
    for entry in totals.values():
        entry["points"] += entry.pop("best_solo")
    return sorted(totals.values(), key=lambda row: (-row["points"], -row["wins"], row["name"]))[:50]


@router.get("/profiles/{user_id}")
def game_profile(user_id: str, db: Session = Depends(get_db),
                 user: User = Depends(get_current_active_validated_user)):
    try:
        key = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(404, "Profil introuvable")
    if db.query(User).filter_by(id=key).first() is None:
        raise HTTPException(404, "Profil introuvable")
    played = db.query(GamePlayer, GameRoom).join(
        GameRoom, GameRoom.id == GamePlayer.room_id).filter(
        GamePlayer.user_id == key, GameRoom.status == "finished").all()
    badges = db.query(Badge.label).join(UserBadge, UserBadge.badge_id == Badge.id).filter(
        UserBadge.user_id == key,
        Badge.name.in_([f"champion_{game}" for game in GAMES])).all()
    solo = [(player, room) for player, room in played if room.game == "quiz"
            and db.query(GamePlayer).filter_by(room_id=room.id).count() == 1]
    solo_ids = {room.id for _, room in solo}
    score = sum(player.score for player, room in played if room.id not in solo_ids)
    score += max((player.score for player, _ in solo), default=0)
    return {"points": score, "wins": sum(int(player.won) for player, _ in played),
            "games": len(played), "badges": [label for (label,) in badges]}
