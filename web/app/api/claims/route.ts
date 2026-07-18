import { NextResponse } from "next/server";
import { getClaimsData } from "@/lib/claims";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export async function GET() {
  const data = await getClaimsData();
  return NextResponse.json(data, {
    headers: {
      "Cache-Control": "public, s-maxage=30, stale-while-revalidate=60",
    },
  });
}
