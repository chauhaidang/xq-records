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

    expect(tableNames).toContain("database_objects");
    expect(tableNames).toContain("database_object_fields");
  });

  it("has the expected indexes and constraints", async () => {
    const indexes: { indexname: string }[] = await prisma.$queryRaw`
      SELECT indexname
      FROM pg_indexes
      WHERE schemaname = 'public'
        AND tablename IN ('database_objects', 'database_object_fields')
    `;
    const indexNames = indexes.map((index) => index.indexname);

    expect(indexNames).toContain("database_objects_identity_unique");
    expect(indexNames).toContain("database_object_fields_name_unique");
    expect(indexNames).toContain("database_object_fields_position_unique");
    expect(indexNames).toContain("idx_database_object_fields_object_id");
  });

  it("has a cascade foreign key from fields to objects", async () => {
    const constraints: {
      constraint_name: string;
      delete_rule: string;
      update_rule: string;
    }[] = await prisma.$queryRaw`
      SELECT rc.constraint_name, rc.delete_rule, rc.update_rule
      FROM information_schema.referential_constraints rc
      WHERE rc.constraint_schema = 'public'
        AND rc.constraint_name = 'database_object_fields_database_object_id_fkey'
    `;

    expect(constraints).toHaveLength(1);
    expect(constraints[0].delete_rule).toBe("CASCADE");
    expect(constraints[0].update_rule).toBe("CASCADE");
  });
});

describe("XQ Records metadata behavior", () => {
  const sourceSchema = `smoke_${Date.now()}`;

  afterEach(async () => {
    await prisma.databaseObject.deleteMany({
      where: { sourceSchema },
    });
  });

  it("creates, reads, and deletes database object metadata with fields", async () => {
    const created = await prisma.databaseObject.create({
      data: {
        sourceSchema,
        objectName: "customer_records",
        objectType: "table",
        displayName: "Customer Records",
        lifecycleStatus: "active",
        ownerName: "records-team",
        tags: ["source", "customer"],
        fields: {
          create: [
            {
              fieldName: "id",
              ordinalPosition: 1,
              dataType: "text",
              isNullable: false,
            },
            {
              fieldName: "email",
              ordinalPosition: 2,
              dataType: "text",
              isNullable: true,
            },
          ],
        },
      },
      include: { fields: true },
    });

    expect(created.fields).toHaveLength(2);

    const readBack = await prisma.databaseObject.findUnique({
      where: { id: created.id },
      include: { fields: true },
    });

    expect(readBack?.objectName).toBe("customer_records");
    expect(readBack?.fields.map((field) => field.fieldName).sort()).toEqual([
      "email",
      "id",
    ]);

    await prisma.databaseObject.delete({ where: { id: created.id } });

    const remainingFields = await prisma.databaseObjectField.count({
      where: { databaseObjectId: created.id },
    });
    expect(remainingFields).toBe(0);
  });

  it("rejects duplicate database object identity", async () => {
    const data = {
      sourceSchema,
      objectName: "orders",
      objectType: "table",
      lifecycleStatus: "active",
    };

    await prisma.databaseObject.create({ data });

    await expect(prisma.databaseObject.create({ data })).rejects.toThrow();
  });

  it("rejects duplicate field names per database object", async () => {
    const object = await prisma.databaseObject.create({
      data: {
        sourceSchema,
        objectName: "products",
        objectType: "table",
      },
    });

    const data = {
      databaseObjectId: object.id,
      fieldName: "sku",
      ordinalPosition: 1,
      dataType: "text",
    };

    await prisma.databaseObjectField.create({ data });

    await expect(
      prisma.databaseObjectField.create({
        data: { ...data, ordinalPosition: 2 },
      })
    ).rejects.toThrow();
  });
});
