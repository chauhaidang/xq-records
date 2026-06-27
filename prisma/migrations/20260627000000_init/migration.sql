-- Initial XQ Records metadata catalog schema.
-- Prisma owns this migration. Keep manual SQL changes aligned with prisma/schema.prisma.

CREATE TABLE "database_objects" (
    "id" TEXT NOT NULL,
    "source_schema" VARCHAR(100) NOT NULL,
    "object_name" VARCHAR(200) NOT NULL,
    "object_type" VARCHAR(50) NOT NULL,
    "display_name" VARCHAR(200),
    "description" TEXT,
    "lifecycle_status" VARCHAR(50) NOT NULL DEFAULT 'active',
    "owner_name" VARCHAR(200),
    "tags" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "version" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "database_objects_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "database_objects_source_schema_not_empty" CHECK (LENGTH(TRIM("source_schema")) > 0),
    CONSTRAINT "database_objects_object_name_not_empty" CHECK (LENGTH(TRIM("object_name")) > 0),
    CONSTRAINT "database_objects_object_type_not_empty" CHECK (LENGTH(TRIM("object_type")) > 0),
    CONSTRAINT "database_objects_lifecycle_status_allowed" CHECK ("lifecycle_status" IN ('active', 'deprecated', 'retired')),
    CONSTRAINT "database_objects_version_positive" CHECK ("version" > 0)
);

CREATE TABLE "database_object_fields" (
    "id" TEXT NOT NULL,
    "database_object_id" TEXT NOT NULL,
    "field_name" VARCHAR(200) NOT NULL,
    "ordinal_position" INTEGER NOT NULL,
    "data_type" VARCHAR(200) NOT NULL,
    "is_nullable" BOOLEAN NOT NULL DEFAULT true,
    "description" TEXT,
    "tags" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "database_object_fields_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "database_object_fields_field_name_not_empty" CHECK (LENGTH(TRIM("field_name")) > 0),
    CONSTRAINT "database_object_fields_data_type_not_empty" CHECK (LENGTH(TRIM("data_type")) > 0),
    CONSTRAINT "database_object_fields_ordinal_position_positive" CHECK ("ordinal_position" > 0)
);

CREATE UNIQUE INDEX "database_objects_identity_unique" ON "database_objects"("source_schema", "object_name", "object_type");
CREATE INDEX "idx_database_objects_source_schema" ON "database_objects"("source_schema");
CREATE INDEX "idx_database_objects_object_type" ON "database_objects"("object_type");
CREATE INDEX "idx_database_objects_lifecycle_status" ON "database_objects"("lifecycle_status");
CREATE INDEX "idx_database_objects_source_name" ON "database_objects"("source_schema", "object_name");
CREATE INDEX "idx_database_objects_tags" ON "database_objects" USING GIN ("tags");

CREATE UNIQUE INDEX "database_object_fields_name_unique" ON "database_object_fields"("database_object_id", "field_name");
CREATE UNIQUE INDEX "database_object_fields_position_unique" ON "database_object_fields"("database_object_id", "ordinal_position");
CREATE INDEX "idx_database_object_fields_object_id" ON "database_object_fields"("database_object_id");
CREATE INDEX "idx_database_object_fields_tags" ON "database_object_fields" USING GIN ("tags");

ALTER TABLE "database_object_fields"
    ADD CONSTRAINT "database_object_fields_database_object_id_fkey"
    FOREIGN KEY ("database_object_id")
    REFERENCES "database_objects"("id")
    ON DELETE CASCADE
    ON UPDATE CASCADE;
