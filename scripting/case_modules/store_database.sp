public void GiveStoreItemForSteamId(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	int m_iStoreId = 0;
	while (SQL_FetchRow(hndl)) {
		m_iStoreId = SQL_FetchInt(hndl, 0);
	}

	if(m_iStoreId > 0)
	{
		ResetPack(pack);

		char cTypeValue[32];
		pack.ReadString(cTypeValue, sizeof(cTypeValue));
		
		char cUniqueIdValue[PLATFORM_MAX_PATH];
		pack.ReadString(cUniqueIdValue, sizeof(cUniqueIdValue));

		char Query[256];
		Format(Query, sizeof(Query), "INSERT INTO `store_items` (`id`, `player_id`, `type`, `unique_id`) VALUES (NULL, '%i', '%s', '%s');", m_iStoreId, cTypeValue, cUniqueIdValue);

		SQL_TQuery(g_DB, SQLHibaKereso, Query);

		delete pack;
	}
}