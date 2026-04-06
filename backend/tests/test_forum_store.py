from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from backend.api.forum_store import ForumStore


class ForumStoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        db = Path(self.tmp.name) / "forum.db"
        self.store = ForumStore(db)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_post_comment_reaction_flow(self) -> None:
        post = self.store.create_post(
            user_id="u1",
            author_name="Parent A",
            title="",
            body="My baby has vaccine fever for one day.",
            country_code="TR",
            child_id="child-a",
            tags=["vaccine", "fever"],
        )
        self.assertEqual(post["reactionCount"], 0)
        self.assertEqual(post["commentCount"], 0)

        comment = self.store.create_comment(
            post_id=post["id"],
            user_id="u2",
            author_name="Parent B",
            body="We had the same reaction, it resolved quickly.",
        )
        self.assertEqual(comment["postId"], post["id"])

        summary = self.store.set_reaction(
            post_id=post["id"],
            user_id="u1",
            reaction="support",
            active=True,
        )
        self.assertEqual(summary["reactionCount"], 1)
        self.assertEqual(summary["viewerReaction"], "support")

        posts = self.store.list_posts(viewer_user_id="u1", country_code="TR", limit=10)
        self.assertEqual(len(posts), 1)
        self.assertEqual(posts[0]["commentCount"], 1)
        self.assertEqual(posts[0]["reactionCount"], 1)

        summary = self.store.set_reaction(
            post_id=post["id"],
            user_id="u1",
            reaction="support",
            active=False,
        )
        self.assertEqual(summary["reactionCount"], 0)
        self.assertEqual(summary["viewerReaction"], "")

    def test_moderation_rejects_blocked_terms(self) -> None:
        with self.assertRaises(ValueError) as context:
            self.store.create_post(
                user_id="u1",
                author_name="Parent A",
                title="Warning",
                body="This is a scam post.",
                country_code="TR",
                child_id="child-a",
                tags=["warning"],
            )
        self.assertEqual(str(context.exception), "blocked_terms")

    def test_rate_limit_applies_per_user(self) -> None:
        rate_limited_store = ForumStore(
            Path(self.tmp.name) / "forum_rate.db",
            post_rate_limit=1,
            post_rate_window_sec=600,
        )
        rate_limited_store.create_post(
            user_id="u1",
            author_name="Parent A",
            title="One",
            body="First post content",
            country_code="TR",
            child_id="child-a",
            tags=[],
        )
        with self.assertRaises(ValueError) as context:
            rate_limited_store.create_post(
                user_id="u1",
                author_name="Parent A",
                title="Two",
                body="Second post content",
                country_code="TR",
                child_id="child-a",
                tags=[],
            )
        self.assertEqual(str(context.exception), "rate_limited")

    def test_report_and_resolve_flow(self) -> None:
        post = self.store.create_post(
            user_id="u1",
            author_name="Parent A",
            title="Question",
            body="We had a mild fever after vaccine.",
            country_code="TR",
            child_id="child-a",
            tags=["vaccine"],
        )

        report = self.store.report_post(
            post_id=post["id"],
            reporter_user_id="u2",
            reason="misinformation",
            note="Needs review",
        )
        self.assertEqual(report["status"], "pending")

        pending = self.store.list_reports(status="pending", limit=10)
        self.assertEqual(len(pending), 1)
        self.assertEqual(pending[0]["id"], report["id"])

        resolved = self.store.resolve_report(
            report_id=report["id"],
            reviewer_user_id="admin-1",
            status="resolved",
        )
        self.assertIsNotNone(resolved)
        assert resolved is not None
        self.assertEqual(resolved["status"], "resolved")
        self.assertEqual(resolved["resolvedByUserId"], "admin-1")

    def test_mute_and_block_filter_feed(self) -> None:
        post_a = self.store.create_post(
            user_id="u1",
            author_name="Parent A",
            title="A",
            body="Post from user one",
            country_code="TR",
            child_id="child-a",
            tags=[],
        )
        post_b = self.store.create_post(
            user_id="u2",
            author_name="Parent B",
            title="B",
            body="Post from user two",
            country_code="TR",
            child_id="child-a",
            tags=[],
        )

        self.store.mute_post(user_id="u3", post_id=post_a["id"])
        feed_u3 = self.store.list_posts(viewer_user_id="u3", country_code="TR", limit=20)
        ids_u3 = [row["id"] for row in feed_u3]
        self.assertNotIn(post_a["id"], ids_u3)
        self.assertIn(post_b["id"], ids_u3)

        self.store.block_user(user_id="u3", target_user_id="u2")
        feed_after_block = self.store.list_posts(viewer_user_id="u3", country_code="TR", limit=20)
        ids_after = [row["id"] for row in feed_after_block]
        self.assertNotIn(post_b["id"], ids_after)


if __name__ == "__main__":
    unittest.main()
