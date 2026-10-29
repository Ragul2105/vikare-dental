"""Add clinical workflow and staff profile fields.

Revision ID: 0002_clinic_ui_fields
Revises: 0001_initial
Create Date: 2026-06-21 00:00:00.000000
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "0002_clinic_ui_fields"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("email", sa.String(length=255), nullable=True))
    op.add_column("users", sa.Column("mobile", sa.String(length=15), nullable=True))
    op.add_column("users", sa.Column("job_title", sa.String(length=100), nullable=True))
    op.add_column("users", sa.Column("schedule", sa.String(length=150), nullable=True))

    op.add_column("patients", sa.Column("blood_type", sa.String(length=10), nullable=True))
    op.add_column(
        "patients",
        sa.Column("clinical_flags", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
    )
    op.add_column(
        "patients",
        sa.Column("was_hospitalized", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column("patients", sa.Column("hospitalization_date", sa.Date(), nullable=True))
    op.add_column("patients", sa.Column("hospitalization_reason", sa.Text(), nullable=True))
    op.add_column("patients", sa.Column("past_dental_history", sa.Text(), nullable=True))

    op.add_column(
        "appointments",
        sa.Column("assigned_practitioner_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.create_index(
        op.f("ix_appointments_assigned_practitioner_id"),
        "appointments",
        ["assigned_practitioner_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_appointments_assigned_practitioner_id_users",
        "appointments",
        "users",
        ["assigned_practitioner_id"],
        ["id"],
    )

    op.add_column(
        "visits",
        sa.Column("follow_up_required", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column("visits", sa.Column("follow_up_date", sa.Date(), nullable=True))
    op.add_column("visits", sa.Column("follow_up_notes", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("visits", "follow_up_notes")
    op.drop_column("visits", "follow_up_date")
    op.drop_column("visits", "follow_up_required")

    op.drop_constraint(
        "fk_appointments_assigned_practitioner_id_users",
        "appointments",
        type_="foreignkey",
    )
    op.drop_index(op.f("ix_appointments_assigned_practitioner_id"), table_name="appointments")
    op.drop_column("appointments", "assigned_practitioner_id")

    op.drop_column("patients", "past_dental_history")
    op.drop_column("patients", "hospitalization_reason")
    op.drop_column("patients", "hospitalization_date")
    op.drop_column("patients", "was_hospitalized")
    op.drop_column("patients", "clinical_flags")
    op.drop_column("patients", "blood_type")

    op.drop_column("users", "schedule")
    op.drop_column("users", "job_title")
    op.drop_column("users", "mobile")
    op.drop_column("users", "email")
