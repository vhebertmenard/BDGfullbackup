trigger LeadTrigger on Lead (before insert,before update) {
   LeadTriggerHandler.leadHandler(trigger.New);
}