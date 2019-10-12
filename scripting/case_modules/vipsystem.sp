#include <viprendszer>

public void VipSystemOnPluginStart()
{
	Case_RegisterModule("vip.month", true, VipOpened);
}

public void VipOpened(Jatekos jatekos, int value) // VR_Hozzaadas(Jatekos admin, Jatekos celpont, Jog jogosultsag, int honap);
{
	VR_Hozzaadas(view_as<Jatekos>(0), jatekos, VIP, value);
}