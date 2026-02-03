trigger BrandTrigger on Lead (before insert,before update) {
	BrandTriggerHandler.brandHandler(trigger.New);
}