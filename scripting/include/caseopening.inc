#if defined _caseopening_included
  #endinput
#endif
#define _caseopening_included

native int Case_RegisterModule(char[] type, bool valuetype = true, Function:fOpened);
native bool Case_IsInventoryLoaded(Jatekos jatekos);
native bool Case_IsBanned(Jatekos jatekos);

native int Case_GiveCaseAmount(Jatekos jatekos, int caseid, int amount);
native int Case_GiveKeyAmount(Jatekos jatekos, int caseid, int amount);

forward void Case_StartOpening(int client, char[] casemodel);
forward void Case_OnCaseOpened(int client, char[] type, char[] value);
forward void Case_OnClientBanned(int admin, int target);

public SharedPlugin __caseopening = 
{
  name = "caseopening",
  file = "caseopening.smx",
#if defined REQUIRE_PLUGIN
  required = 1,
#else
  required = 0,
#endif
};
