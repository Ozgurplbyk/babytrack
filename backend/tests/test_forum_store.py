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
        self.assertEqual(pending[0]["postTitle"], "Question")
        self.assertEqual(pending[0]["postAuthorName"], "Parent A")
        self.assertIn("mild fever", pending[0]["postBody"])

        resolved = self.store.resolve_report(
            report_id=report["id"],
            reviewer_user_id="admin-1",
            status="resolved",
        )
        self.assertIsNotNone(resolved)
        assert resolved is not None
        self.assertEqual(resolved["status"], "resolved")
        self.assertEqual(resolved["resolvedByUserId"], "admin-1")

        all_reports = self.store.list_reports(status="", limit=10)
        self.assertEqual(all_reports[0]["resolvedByUserId"], "admin-1")

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

    def test_post_filters_support_query_tag_and_scope(self) -> None:
        mine = self.store.create_post(
            user_id="u1",
            author_name="Parent A",
            title="Sleep regression",
            body="Looking for tips about four month sleep regression.",
            country_code="TR",
            child_id="child-a",
            tags=["sleep", "month4"],
        )
        other = self.store.create_post(
            user_id="u2",
            author_name="Parent B",
            title="Bottle refusal",
            body="My baby refuses formula bottle in the evening.",
            country_code="TR",
            child_id="child-a",
            tags=["feeding", "bottle"],
        )

        by_query = self.store.list_posts(
            viewer_user_id="u1",
            country_code="TR",
            limit=20,
            query="sleep regression",
        )
        self.assertEqual([row["id"] for row in by_query], [mine["id"]])

        by_tag = self.store.list_posts(
            viewer_user_id="u1",
            country_code="TR",
            limit=20,
            tag="bottle",
        )
        self.assertEqual([row["id"] for row in by_tag], [other["id"]])

        mine_only = self.store.list_posts(
            viewer_user_id="u1",
            country_code="TR",
            limit=20,
            author_scope="mine",
        )
        self.assertEqual([row["id"] for row in mine_only], [mine["id"]])

    def test_owner_can_update_post(self) -> None:
        post = self.store.create_post(
            user_id="u1",
            author_name="Parent A",
            title="Original title",
            body="Original body for the community forum.",
            country_code="TR",
            child_id="child-a",
            tags=["sleep"],
        )

        updated = self.store.update_post(
            post_id=post["id"],
            user_id="u1",
            title="Updated title",
            body="Updated body with clearer details for other parents.",
            tags=["sleep", "routine"],
        )

        self.assertEqual(updated["id"], post["id"])
        self.assertEqual(updated["title"], "Updated title")
        self.assertEqual(updated["body"], "Updated body with clearer details for other parents.")
        self.assertEqual(updated["tags"], ["sleep", "routine"])
        self.assertGreaterEqual(updated["updatedAt"], post["updatedAt"])

    def test_non_owner_cannot_update_post(self) -> None:
        post = self.store.create_post(
            user_id="u1",
            author_name="Parent A",
            title="Original title",
            body="Original body for the community forum.",
            country_code="TR",
            child_id="child-a",
            tags=["sleep"],
        )

        with self.assertRaises(ValueError) as context:
            self.store.update_post(
                post_id=post["id"],
                user_id="u2",
                title="Bad edit",
                body="Trying to edit someone else's post.",
                tags=["sleep"],
            )
        self.assertEqual(str(context.exception), "forbidden")

    def test_owner_can_delete_post_and_related_content(self) -> None:
        post = self.store.create_post(
            user_id="u1",
            author_name="Parent A",
            title="Question",
            body="How did your babies react to this vaccine?",
            country_code="TR",
            child_id="child-a",
            tags=["vaccine"],
        )

        self.store.create_comment(
            post_id=post["id"],
            user_id="u2",
            author_name="Parent B",
            body="Mine had a mild fever for one evening.",
        )
        self.store.set_reaction(
            post_id=post["id"],
            user_id="u3",
            reaction="support",
            active=True,
        )
        self.store.report_post(
            post_id=post["id"],
            reporter_user_id="u4",
            reason="safety",
            note="Needs review",
        )
        self.store.mute_post(user_id="u5", post_id=post["id"])

        deleted = self.store.delete_post(post_id=post["id"], user_id="u1")
        self.assertTrue(deleted)
        self.assertEqual(self.store.list_posts(viewer_user_id="u1", country_code="TR", limit=20), [])
        self.assertEqual(self.store.list_comments(post["id"]), [])
        self.assertEqual(self.store.list_reports(status="pending", limit=20), [])

        deleted_again = self.store.delete_post(post_id=post["id"], user_id="u1")
        self.assertFalse(deleted_again)

    def test_bookmark_flow_and_saved_scope(self) -> None:
        mine = self.store.create_post(
            user_id="u1",
            author_name="Parent A",
            title="Sleep tips",
            body="Sharing a few routines that helped our evenings.",
            country_code="TR",
            child_id="child-a",
            tags=["sleep"],
        )
        other = self.store.create_post(
            user_id="u2",
            author_name="Parent B",
            title="Bottle tips",
            body="Bottle feeding tips for the late evening stretch.",
            country_code="TR",
            child_id="child-a",
            tags=["feeding"],
        )

        bookmarked = self.store.set_bookmark(user_id="u9", post_id=other["id"], active=True)
        self.assertTrue(bookmarked["viewerBookmarked"])

        saved = self.store.list_posts(
            viewer_user_id="u9",
            country_code="TR",
            limit=20,
            author_scope="saved",
        )
        self.assertEqual([row["id"] for row in saved], [other["id"]])

        unbookmarked = self.store.set_bookmark(user_id="u9", post_id=other["id"], active=False)
        self.assertFalse(unbookmarked["viewerBookmarked"])

        saved_after = self.store.list_posts(
            viewer_user_id="u9",
            country_code="TR",
            limit=20,
            author_scope="saved",
        )
        self.assertEqual(saved_after, [])

    def test_post_history_includes_current_and_previous_versions(self) -> None:
        post = self.store.create_post(
            user_id="u1",
            author_name="Parent A",
            title="Original title",
            body="Original body for revision history.",
            country_code="TR",
            child_id="child-a",
            tags=["sleep"],
        )

        self.store.update_post(
            post_id=post["id"],
            user_id="u1",
            title="Updated title",
            body="First revision body.",
            tags=["sleep", "routine"],
        )
        self.store.update_post(
            post_id=post["id"],
            user_id="u1",
            title="Updated title 2",
            body="Second revision body.",
            tags=["routine"],
        )

        history = self.store.list_post_history(post_id=post["id"], user_id="u1")
        self.assertEqual(len(history), 3)
        self.assertTrue(history[0]["isCurrent"])
        self.assertEqual(history[0]["title"], "Updated title 2")
        self.assertEqual(history[1]["title"], "Updated title")
        self.assertFalse(history[1]["isCurrent"])
        self.assertEqual(history[2]["title"], "Original title")
        self.assertEqual(history[2]["body"], "Original body for revision history.")

    def test_post_history_forbidden_for_non_owner(self) -> None:
        post = self.store.create_post(
            user_id="u1",
            author_name="Parent A",
            title="Original title",
            body="Original body for revision history.",
            country_code="TR",
            child_id="child-a",
            tags=["sleep"],
        )
        self.store.update_post(
            post_id=post["id"],
            user_id="u1",
            title="Updated title",
            body="Updated body.",
            tags=["routine"],
        )

        with self.assertRaises(ValueError) as context:
            self.store.list_post_history(post_id=post["id"], user_id="u2")
        self.assertEqual(str(context.exception), "forbidden")


if __name__ == "__main__":
    unittest.main()
