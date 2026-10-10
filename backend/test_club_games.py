import unittest

from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.db.database import Base
import app.models.base  # noqa: F401
from app.api.routes.games import (
    CreateRoom, JoinRoom, SubmitResponse, answer_room, create_room,
    eliminate, game_profile, join_room, leaderboard, next_round,
    players_for, public_room, start_room,
)
from app.models.gamification import UserBadge
from app.models.games import GameRoom
from app.models.user import User
from app.services.game_content import ICEBREAKERS, QUIZ, UNDERCOVER, choose, choose_quiz


def member(n):
    return User(first_name=f"Joueur{n}", last_name="Test",
                email=f"joueur{n}@example.test", password_hash="test",
                status="active", email_verified=True)


class ClubGamesTest(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.db = Session(self.engine)
        self.users = [member(n) for n in range(5)]
        self.db.add_all(self.users)
        self.db.commit()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()

    def room(self, game, players):
        response = create_room(CreateRoom(game=game), db=self.db,
                               user=self.users[0])
        for person in self.users[1:players]:
            join_room(JoinRoom(code=response["code"]), db=self.db, user=person)
        return str(response["id"])

    def test_quiz_ranking_badge_and_idempotent_answers(self):
        room_id = self.room("quiz", 2)
        start_room(room_id, db=self.db, user=self.users[0])
        room = self.db.query(GameRoom).one()
        key = str(room.state["correct"])
        public = public_room(self.db, room, self.users[1])
        self.assertNotIn("correct", str(public))
        answer_room(room_id, SubmitResponse(answer=key), self.db, self.users[0])
        with self.assertRaises(HTTPException) as failure:
            answer_room(room_id, SubmitResponse(answer=key), self.db, self.users[0])
        self.assertEqual(failure.exception.status_code, 409)
        answer_room(room_id, SubmitResponse(answer=str((int(key) + 1) % 4)),
                    self.db, self.users[1])
        for _ in range(4):
            next_round(room_id, db=self.db, user=self.users[0])
            key = str(room.state["correct"])
            answer_room(room_id, SubmitResponse(answer=key), self.db, self.users[0])
            answer_room(room_id, SubmitResponse(answer=str((int(key) + 1) % 4)),
                        self.db, self.users[1])
        next_round(room_id, db=self.db, user=self.users[0])
        self.assertEqual(room.status, "finished")
        self.assertEqual(self.db.query(UserBadge).count(), 1)
        self.assertEqual(leaderboard(game='quiz', db=self.db,
                                      user=self.users[0])[0]['wins'], 1)
        self.assertIn('Champion quiz', game_profile(str(self.users[0].id),
                       self.db, self.users[0])['badges'])
        self.assertTrue(public_room(self.db, room, self.users[0])["my_won"])

    def test_solo_quiz_uses_best_score_without_champion_badge(self):
        for _ in range(2):
            room_id = self.room("quiz", 1)
            room = self.db.query(GameRoom).filter_by(id=room_id).first()
            room.max_rounds = 1
            self.db.commit()
            start_room(room_id, db=self.db, user=self.users[0])
            answer_room(room_id, SubmitResponse(answer=str(room.state["correct"])),
                        self.db, self.users[0])
            next_round(room_id, db=self.db, user=self.users[0])
        ranking = leaderboard(game="quiz", db=self.db, user=self.users[0])
        self.assertEqual(ranking[0]["points"], 10)
        self.assertEqual(ranking[0]["games"], 2)
        self.assertEqual(ranking[0]["wins"], 0)
        self.assertEqual(self.db.query(UserBadge).count(), 0)
        self.assertEqual(game_profile(str(self.users[0].id),
                         self.db, self.users[0])["points"], 10)

    def test_undercover_secrets_stay_private_and_vote(self):
        room_id = self.room("undercover", 3)
        start_room(room_id, db=self.db, user=self.users[0])
        room = self.db.query(GameRoom).one()
        people = [public_room(self.db, room, user) for user in self.users[:3]]
        self.assertEqual(sum(item["my_role"] == "undercover" for item in people), 1)
        for item in people:
            self.assertNotIn("pair", str(item["prompt"]))
            self.assertTrue(all(p["role"] is None for p in item["players"]))
        spy = next(item for item in people if item["my_role"] == "undercover")
        for user in self.users[:3]:
            if str(user.id) != spy["my_id"]:
                answer_room(room_id, SubmitResponse(answer=spy["my_id"]),
                            self.db, user)
            else:
                target = next(p["id"] for p in spy["players"] if p["id"] != spy["my_id"])
                answer_room(room_id, SubmitResponse(answer=target), self.db, user)
        next_round(room_id, db=self.db, user=self.users[0])
        self.assertEqual(room.status, "finished")
        self.assertEqual(self.db.query(UserBadge).count(), 2)

    def test_cupid_picks_two_lovers(self):
        room_id = self.room("werewolf", 4)
        start_room(room_id, db=self.db, user=self.users[0])
        room = self.db.query(GameRoom).one()
        cupid = next(user for user in self.users[:4]
                     if public_room(self.db, room, user)["my_role"] == "cupid")
        choices = [str(user.id) for user in self.users[:2]]
        result = answer_room(room_id, SubmitResponse(answer=",".join(choices)),
                             self.db, cupid)
        self.assertEqual(result["phase"], "night")
        self.assertEqual(room.state["lovers"], choices)
        people = players_for(self.db, room)
        linked = next(person for person in people if str(person.user_id) == choices[0])
        eliminate(room, linked, people)
        self.assertTrue(all(person.eliminated for person in people
                            if str(person.user_id) in choices))
        for user in self.users[:2]:
            self.assertEqual(public_room(self.db, room, user)["lovers"], choices)
        stranger = next(user for user in self.users[:4] if user != cupid)
        if str(stranger.id) not in choices:
            self.assertIsNone(public_room(self.db, room, stranger)["lovers"])

    def test_werewolf_night_eliminates_linked_lovers(self):
        room_id = self.room("werewolf", 4)
        start_room(room_id, db=self.db, user=self.users[0])
        room = self.db.query(GameRoom).one()
        people = players_for(self.db, room)
        cupid = next(p for p in people if p.role == "cupid")
        wolf = next(p for p in people if p.role == "wolf")
        others = [p for p in people if p not in (cupid, wolf)]
        ids = [str(p.user_id) for p in others]
        user_cupid = next(u for u in self.users if u.id == cupid.user_id)
        user_wolf = next(u for u in self.users if u.id == wolf.user_id)
        answer_room(room_id, SubmitResponse(answer=",".join(ids)), self.db, user_cupid)
        answer_room(room_id, SubmitResponse(answer=ids[0]), self.db, user_wolf)
        next_round(room_id, db=self.db, user=self.users[0])
        self.assertTrue(all(p.eliminated for p in others))
        self.assertEqual(room.status, "finished")
        self.assertTrue(wolf.won)

    def test_private_room_and_team_victory(self):
        room = create_room(CreateRoom(game="quiz", mode="team", rounds=1),
                           db=self.db, user=self.users[0])
        with self.assertRaises(HTTPException) as forbidden:
            public_room(self.db, self.db.query(GameRoom).one(), self.users[1])
        self.assertEqual(forbidden.exception.status_code, 403)
        join_room(JoinRoom(code=room["code"], team="B"), self.db, self.users[1])
        room_id = room["id"]
        start_room(room_id, db=self.db, user=self.users[0])
        correct = self.db.query(GameRoom).one().state["correct"]
        answer_room(room_id, SubmitResponse(answer=str(correct)), self.db, self.users[0])
        answer_room(room_id, SubmitResponse(answer=str((correct + 1) % 4)),
                    self.db, self.users[1])
        next_round(room_id, db=self.db, user=self.users[0])
        self.assertEqual(self.db.query(UserBadge).count(), 1)
        self.assertFalse(public_room(self.db, self.db.query(GameRoom).one(),
                                     self.users[1])["my_won"])

    def test_shuffling_exhausts_pool_before_repeat(self):
        used = []
        for _ in range(len(UNDERCOVER["quotidien"])):
            choose(UNDERCOVER, "quotidien", used)
        self.assertEqual(len(set(used)), len(UNDERCOVER["quotidien"]))
        asked = []
        for _ in range(len(ICEBREAKERS["fun"])):
            choose(ICEBREAKERS, "fun", asked)
        self.assertEqual(len(set(asked)), len(ICEBREAKERS["fun"]))
        quiz_used = []
        for _ in range(len(QUIZ)):
            choose_quiz("mix", quiz_used)
        self.assertEqual(len(set(quiz_used)), len(QUIZ))


if __name__ == "__main__":
    unittest.main()
