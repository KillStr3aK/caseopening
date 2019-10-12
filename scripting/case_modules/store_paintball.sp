public void StorePaintballOnPluginStart()
{
	Case_RegisterModule("store.paintball", false, PaintballOpened);
}

public void PaintballOpened(Jatekos jatekos, char[] paintball)
{
	char authid[20];
	GetLegacyAuthString(jatekos.index, authid, sizeof(authid));

	char Query[1024];
	Format(Query, sizeof(Query), "SELECT id FROM store_players WHERE authid = '%s'", authid);

	DataPack things = new DataPack();
	things.WriteString("paintball");
	things.WriteString(paintball)

	SQL_TQuery(g_DB, GiveStoreItemForSteamId, Query, things);
}