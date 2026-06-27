import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../generated/prisma/client";

const DATABASE_URL =
  process.env.DATABASE_URL ||
  "postgresql://xq_records_user:xq_records_password@localhost:5432/xq-records?schema=public";

const adapter = new PrismaPg({ connectionString: DATABASE_URL });
const prisma = new PrismaClient({ adapter });

afterAll(async () => {
  await prisma.$disconnect();
});

describe("XQ Records database connectivity", () => {
  it("connects to the configured database", async () => {
    const result: [{ current_database: string }] =
      await prisma.$queryRaw`SELECT current_database()`;

    expect(result[0].current_database).toBeTruthy();
  });
});

describe("XQ Records table structure", () => {
  it("has the expected public tables", async () => {
    const tables: { table_name: string }[] = await prisma.$queryRaw`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_type = 'BASE TABLE'
      ORDER BY table_name
    `;
    const tableNames = tables.map((table) => table.table_name);

    expect(tableNames).toContain("object_types");
    expect(tableNames).toContain("objects");
    expect(tableNames).toContain("object_versions");
  });

  it("has the expected indexes and constraints", async () => {
    const indexes: { indexname: string }[] = await prisma.$queryRaw`
      SELECT indexname
      FROM pg_indexes
      WHERE schemaname = 'public'
        AND tablename IN ('object_types', 'objects', 'object_versions')
    `;
    const indexNames = indexes.map((index) => index.indexname);

    expect(indexNames).toContain("object_types_name_key");
    expect(indexNames).toContain("objects_identity_unique");
    expect(indexNames).toContain("idx_objects_origin_source");
    expect(indexNames).toContain("object_versions_object_version_unique");
  });

  it("has cascade history and restricted type foreign keys", async () => {
    const constraints: {
      constraint_name: string;
      delete_rule: string;
      update_rule: string;
    }[] = await prisma.$queryRaw`
      SELECT rc.constraint_name, rc.delete_rule, rc.update_rule
      FROM information_schema.referential_constraints rc
      WHERE rc.constraint_schema = 'public'
        AND rc.constraint_name IN (
          'objects_object_type_id_fkey',
          'object_versions_object_id_fkey',
          'objects_current_version_id_fkey'
        )
      ORDER BY rc.constraint_name
    `;

    expect(constraints).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          constraint_name: "objects_object_type_id_fkey",
          delete_rule: "RESTRICT",
        }),
        expect.objectContaining({
          constraint_name: "object_versions_object_id_fkey",
          delete_rule: "CASCADE",
        }),
        expect.objectContaining({
          constraint_name: "objects_current_version_id_fkey",
          delete_rule: "SET NULL",
        }),
      ])
    );
  });
});

describe("XQ Records abstract object behavior", () => {
  const typeNamePrefix = `smoke_${Date.now()}`;

  afterEach(async () => {
    const smokeTypes = await prisma.objectType.findMany({
      where: { name: { startsWith: typeNamePrefix } },
      select: { id: true },
    });
    const smokeTypeIds = smokeTypes.map((type) => type.id);

    if (smokeTypeIds.length > 0) {
      await prisma.object.deleteMany({
        where: { objectTypeId: { in: smokeTypeIds } },
      });
    }

    await prisma.objectType.deleteMany({
      where: { name: { startsWith: typeNamePrefix } },
    });
  });

  it("creates an object type, object with origin source, and version history", async () => {
    const typeName = `${typeNamePrefix}_history`;
    const objectType = await prisma.objectType.create({
      data: {
        name: typeName,
        displayName: "Smoke Object",
        schemaJson: {
          required: ["name"],
          properties: {
            name: { type: "string" },
          },
        },
      },
    });

    const object = await prisma.object.create({
      data: {
        objectTypeId: objectType.id,
        externalKey: "bench_press",
        originSource: "xq_fitness.exercises",
        versions: {
          create: [
            {
              version: 1,
              data: {
                name: "Bench Press",
                muscleGroup: "Chest",
              },
              changeReason: "initial import",
            },
          ],
        },
      },
      include: { versions: true },
    });

    expect(object.originSource).toBe("xq_fitness.exercises");
    expect(object.versions).toHaveLength(1);
    expect(object.versions[0].version).toBe(1);

    await prisma.object.update({
      where: { id: object.id },
      data: { currentVersionId: object.versions[0].id },
    });

    const readBack = await prisma.object.findUnique({
      where: { id: object.id },
      include: {
        objectType: true,
        currentVersion: true,
        versions: true,
      },
    });

    expect(readBack?.objectType.name).toBe(typeName);
    expect(readBack?.currentVersion?.version).toBe(1);
    expect(readBack?.versions).toHaveLength(1);
  });

  it("rejects duplicate object identity within type, origin source, and external key", async () => {
    const typeName = `${typeNamePrefix}_duplicate_identity`;
    const objectType = await prisma.objectType.create({
      data: { name: typeName },
    });

    const data = {
      objectTypeId: objectType.id,
      externalKey: "order-123",
      originSource: "commerce.orders",
    };

    await prisma.object.create({ data });

    await expect(prisma.object.create({ data })).rejects.toThrow();
  });

  it("allows the same external key from a different origin source", async () => {
    const typeName = `${typeNamePrefix}_origin_source`;
    const objectType = await prisma.objectType.create({
      data: { name: typeName },
    });

    await prisma.object.create({
      data: {
        objectTypeId: objectType.id,
        externalKey: "asset-123",
        originSource: "finance.assets",
      },
    });

    const second = await prisma.object.create({
      data: {
        objectTypeId: objectType.id,
        externalKey: "asset-123",
        originSource: "inventory.assets",
      },
    });

    expect(second.originSource).toBe("inventory.assets");
  });

  it("deletes version history when an object is deleted", async () => {
    const typeName = `${typeNamePrefix}_cascade_history`;
    const objectType = await prisma.objectType.create({
      data: { name: typeName },
    });
    const object = await prisma.object.create({
      data: {
        objectTypeId: objectType.id,
        externalKey: "routine-a",
        originSource: "xq_fitness.workout_routines",
        versions: {
          create: [
            { version: 1, data: { name: "Routine A" } },
            { version: 2, data: { name: "Routine A Updated" } },
          ],
        },
      },
      include: { versions: true },
    });

    await prisma.object.delete({ where: { id: object.id } });

    const remainingVersions = await prisma.objectVersion.count({
      where: { objectId: object.id },
    });
    expect(remainingVersions).toBe(0);
  });
});
