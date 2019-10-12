#if defined _caseopening_included
  #endinput
#endif
#define _caseopening_included

native int Case_RegisterModule(char[] type, bool valuetype = true, Function:fOpened);
native bool Case_IsInventoryLoaded(Jatekos jatekos)

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
