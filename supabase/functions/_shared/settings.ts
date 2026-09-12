export async function settingNumber(admin: any, key: string, fallback: number): Promise<number> {
  const { data } = await admin.from("app_settings").select("value").eq("key", key).single();
  return data ? Number(data.value) : fallback;
}

export async function settingBool(admin: any, key: string, fallback: boolean): Promise<boolean> {
  const { data } = await admin.from("app_settings").select("value").eq("key", key).single();
  return data ? Boolean(data.value) : fallback;
}
