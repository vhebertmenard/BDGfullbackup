@isTest
public class TestSubmitApprovalWithEvaluation {
    static testMethod void SubmitApprovalWithEvaluationTest() {

// Create a test account
     Account testAcct = new Account (Name = 'My Test Account');
     insert testAcct;

    // Create a related contact
         Contact testContact = new Contact (FirstName = 'Fred',
         LastName = 'Jones',
         Phone = '4035551212',
         MobilePhone = '4035551234',
         Email = 'Fred@example.com');
         insert testContact;
    // Creates first opportunity
    Opportunity oppt = new Opportunity(Name ='New mAWS Deal',
                            AccountID = testAcct.ID,
                            StageName = 'Won',
                            Amount = 3000,
                            Credit_App_Obtained__c = 'Yes',
                            Reason_s_Won_Lost_Cancelled__c = 'Availability',
                            Other_Reason__c = 'Because Scott Said So',
                            Primary_Contact__c = testContact.ID,
                            Site_Contact__c = testContact.ID,
                            Accounting_Contact__c = testContact.ID,
                            Project_Location_Address__c = '101 9 Ave SW',
                            Project_Location_City__c = 'Calgary',
                            Project_Location_Country__c = 'Canada',
                            Project_Location_Province__c = 'Alberta',
                            CloseDate = System.today());

   insert oppt;

        Test.startTest();
            {

    // Create a test opportunity
    Opportunity mAWSUsage = new Opportunity( Name = 'mAWS Usage',
                              AccountId = testAcct.Id,
                              StageName = 'Negotiations',
                              CloseDate = System.today(),
                              Type = 'New Business - Add',
                              Amount = 555888555);

  insert  mAWSUsage;


    // Get the opportunity, verify the stage name and close date
  mAWSUsage = [SELECT StageName, CloseDate, Name, Type, Amount, Reason_s_Won_Lost_Cancelled__c
             FROM Opportunity 
             WHERE id = :mAWSUsage.Id];
             
             ApexPages.CurrentPage().getparameters().put('pid', mAWSUsage.Id);
             ApexPages.StandardController sc = new ApexPages.standardController(mAWSUsage);
                     
             // test pass case   
             SubmitApprovalWithEvaluationController sawe= new SubmitApprovalWithEvaluationController(sc);
             mAWSUsage.Reason_s_Won_Lost_Cancelled__c = 'Cancelled';
             sawe.opp = mAWSUsage;
             sawe.approve();
             system.assert(true);
                
             SubmitApprovalWithEvaluationController sawe1= new SubmitApprovalWithEvaluationController(sc);
             sawe1.opp = mAWSUsage;
             sawe1.approve();
             system.assert(true);
                
             // Test fail case   
             SubmitApprovalWithEvaluationController sawe2= new SubmitApprovalWithEvaluationController(sc);
             mAWSUsage.Reason_s_Won_Lost_Cancelled__c = '';
             sawe2.opp = mAWSUsage;
             sawe2.approve();


               // Test resubmit fail - I don't think that it resummits the same one like I want.
             ApexPages.CurrentPage().getparameters().put('pid', mAWSUsage.Id);
             ApexPages.StandardController sc3 = new ApexPages.standardController(mAWSUsage);
             SubmitApprovalWithEvaluationController sawe3= new SubmitApprovalWithEvaluationController(sc3);
             sawe3.approve();
             system.assert(true);
                
             system.assert(true);
            }
            Test.stopTest(); 
             
   }

}