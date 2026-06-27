-- Initial XQ Records abstract object history schema.
-- Prisma owns this migration. Keep manual SQL changes aligned with prisma/schema.prisma.

CREATE TABLE "object_types" (
    "id" TEXT NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "display_name" VARCHAR(200),
    "description" TEXT,
    "schema_json" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "object_types_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "object_types_name_not_empty" CHECK (LENGTH(TRIM("name")) > 0)
);

CREATE TABLE "objects" (
    "id" TEXT NOT NULL,
    "object_type_id" TEXT NOT NULL,
    "external_key" VARCHAR(200) NOT NULL,
    "origin_source" VARCHAR(200) NOT NULL,
    "status" VARCHAR(50) NOT NULL DEFAULT 'active',
    "current_version_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "objects_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "objects_external_key_not_empty" CHECK (LENGTH(TRIM("external_key")) > 0),
    CONSTRAINT "objects_origin_source_not_empty" CHECK (LENGTH(TRIM("origin_source")) > 0),
    CONSTRAINT "objects_status_allowed" CHECK ("status" IN ('active', 'archived', 'deleted'))
);

CREATE TABLE "object_versions" (
    "id" TEXT NOT NULL,
    "object_id" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "data" JSONB NOT NULL,
    "change_reason" TEXT,
    "valid_from" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "valid_to" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "object_versions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "object_versions_version_positive" CHECK ("version" > 0),
    CONSTRAINT "object_versions_valid_range" CHECK ("valid_to" IS NULL OR "valid_to" > "valid_from")
);

CREATE UNIQUE INDEX "object_types_name_key" ON "object_types"("name");
CREATE INDEX "idx_object_types_name" ON "object_types"("name");

CREATE UNIQUE INDEX "objects_identity_unique" ON "objects"("object_type_id", "origin_source", "external_key");
CREATE UNIQUE INDEX "objects_current_version_id_key" ON "objects"("current_version_id");
CREATE INDEX "idx_objects_object_type_id" ON "objects"("object_type_id");
CREATE INDEX "idx_objects_origin_source" ON "objects"("origin_source");
CREATE INDEX "idx_objects_status" ON "objects"("status");
CREATE INDEX "idx_objects_external_key" ON "objects"("external_key");

CREATE UNIQUE INDEX "object_versions_object_version_unique" ON "object_versions"("object_id", "version");
CREATE INDEX "idx_object_versions_object_id" ON "object_versions"("object_id");
CREATE INDEX "idx_object_versions_valid_from" ON "object_versions"("valid_from");
CREATE INDEX "idx_object_versions_data" ON "object_versions" USING GIN ("data");

ALTER TABLE "objects"
    ADD CONSTRAINT "objects_object_type_id_fkey"
    FOREIGN KEY ("object_type_id")
    REFERENCES "object_types"("id")
    ON DELETE RESTRICT
    ON UPDATE CASCADE;

ALTER TABLE "objects"
    ADD CONSTRAINT "objects_current_version_id_fkey"
    FOREIGN KEY ("current_version_id")
    REFERENCES "object_versions"("id")
    ON DELETE SET NULL
    ON UPDATE CASCADE;

ALTER TABLE "object_versions"
    ADD CONSTRAINT "object_versions_object_id_fkey"
    FOREIGN KEY ("object_id")
    REFERENCES "objects"("id")
    ON DELETE CASCADE
    ON UPDATE CASCADE;
