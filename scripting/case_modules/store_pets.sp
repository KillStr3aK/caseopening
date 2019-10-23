public void StorePetOnPluginStart()
{
	Case_RegisterModule("store.pet", false, PetOpened);
}

public void PetOpened(Jatekos jatekos, char[] pet)
{
	char authid[20];
	jatekos.GetAuthId(AuthId_Steam2, authid, sizeof(authid));
	if (StrContains(authid, "STEAM_") != -1) strcopy(authid, sizeof(authid), authid[8]);

	char Query[1024];
	Format(Query, sizeof(Query), "SELECT id FROM store_players WHERE authid = '%s'", authid);

	DataPack things = new DataPack();
	things.WriteString("pet");
	things.WriteString(pet)

	SQL_TQuery(g_DB, GiveStoreItemForSteamId, Query, things);
}