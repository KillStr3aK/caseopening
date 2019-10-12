#include <store>

public void StoreCreditsOnPluginStart()
{
	Case_RegisterModule("store.credit", true, CreditsOpened);
}

public void CreditsOpened(Jatekos jatekos, int value)
{
	Store_SetClientCredits(jatekos.index, Store_GetClientCredits(jatekos.index) + value);
}