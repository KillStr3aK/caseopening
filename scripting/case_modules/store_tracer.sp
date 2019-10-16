public void StoreTracerOnPluginStart()
{
	Case_RegisterModule("store.tracer", false, TracerOpened);
}

public void TracerOpened(Jatekos jatekos, char[] tracer)
{
	char authid[20];
	GetLegacyAuthString(jatekos.index, authid, sizeof(authid));

	char Query[1024];
	Format(Query, sizeof(Query), "SELECT id FROM store_players WHERE authid = '%s'", authid);

	DataPack things = new DataPack();
	things.WriteString("tracer");
	things.WriteString(tracer)

	SQL_TQuery(g_DB, GiveStoreItemForSteamId, Query, things);
}