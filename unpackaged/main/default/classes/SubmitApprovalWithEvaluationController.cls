public class SubmitApprovalWithEvaluationController {
    public Opportunity opp;
    public SubmitApprovalWithEvaluationController (ApexPages.StandardController stdController){
        this.opp = (Opportunity)stdController.getRecord();
    }

    public PageReference approve() {
        System.debug('OppID = '+opp.Id);
        Approval.ProcessSubmitRequest req1 = new Approval.ProcessSubmitRequest();
        req1.setComments('Submitting request for approval.');
        req1.setObjectId(opp.id);

        if (String.isBlank(opp.Reason_s_Won_Lost_Cancelled__c))     {
            opp.Reason_s_Won_Lost_Cancelled__c.addError('Please provide the reason this opportunity is being cancelled before submitting to cancel.');
            return null;
        }

        // Submit the record to specific process and skip the criteria evaluation
        req1.setProcessDefinitionNameOrId('SFDC_Approval_for_Cancelled_Opportunity');
        req1.setSkipEntryCriteria(false);
               
        try    {
            // Submit the approval request for the account
            Approval.ProcessResult result = Approval.process(req1);
        }
        catch(DmlException e)  {
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.FATAL,'Unable to process.  Did you already submit it?  DmlException: "' + e.getMessage() + '"'));
            return null;        
        }      
         
        PageReference oppPage = new PageReference('/'+opp.Id);
        oppPage.setRedirect(true);
        return oppPage;
    }
}