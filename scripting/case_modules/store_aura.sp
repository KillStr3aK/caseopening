public void StoreAuraOnPluginStart()
{
	Case_RegisterModule("store.aura", false, AuraOpened);
}

public void AuraOpened(Jatekos jatekos, char[] aura)
{
	char authid[20];
	GetLegacyAuthString(jatekos.index, authid, sizeof(authid));

	char Query[1024];
	Format(Query, sizeof(Query), "SELECT id FROM store_players WHERE authid = '%s'", authid);

	DataPack things = new DataPack();
	things.WriteString("aura");
	things.WriteString(aura)

	SQL_TQuery(g_DB, GiveStoreItemForSteamId, Query, things);
}