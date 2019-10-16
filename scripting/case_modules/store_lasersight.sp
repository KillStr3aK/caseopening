public void StoreLaserSightOnPluginStart()
{
	Case_RegisterModule("store.lasersight", false, LaserSightOpened);
}

public void LaserSightOpened(Jatekos jatekos, char[] lasersight)
{
	char authid[20];
	GetLegacyAuthString(jatekos.index, authid, sizeof(authid));

	char Query[1024];
	Format(Query, sizeof(Query), "SELECT id FROM store_players WHERE authid = '%s'", authid);

	DataPack things = new DataPack();
	things.WriteString("lasersight");
	things.WriteString(lasersight)

	SQL_TQuery(g_DB, GiveStoreItemForSteamId, Query, things);
}