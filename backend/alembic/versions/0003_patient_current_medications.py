"""Add current medications to patient records.

Revision ID: 0003_patient_current_medications
Revises: 0002_clinic_ui_fields
Create Date: 2026-06-26 00:00:00.000000
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0003_patient_current_medications"
down_revision = "0002_clinic_ui_fields"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("patients", sa.Column("current_medications", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("patients", "current_medications")
