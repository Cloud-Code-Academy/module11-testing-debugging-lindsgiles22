@isTest
public class LeadTriggerHandlerTest {
    // Utility method to create Lead with customizable fields
    private static Lead createTestLead(String email, String title, String company, Boolean insertNow) {
        Lead testlead = new Lead(
            FirstName ='Test',
            LastName = 'User',
            Company = company,
            Email = email,
            Title = title
            );
            if(insertNow) {
                insert testLead;
            }
            return testLead;
        }

        @isTest
        static void testHandleTitleNormalizationVariants() {
        List<Lead> testLeads = new List<Lead>{
            new Lead(FirstName='Test', LastName='VP', Company='Company A', Title='vp', Email='vp1@test.com'),
            new Lead(FirstName='Test', LastName='VP2', Company='Company A', Title='v.p.', Email='vp2@test.com'),
            new Lead(FirstName='Test', LastName='Vice', Company='Company A', Title='vice president', Email='vp3@test.com'),
            new Lead(FirstName='Test', LastName='Mgr', Company='Company A', Title='mgr', Email='mgr@test.com'),
            new Lead(FirstName='Test', LastName='Manager', Company='Company A', Title='manage', Email='mgr2@test.com'),
            new Lead(FirstName='Test', LastName='HeadDept', Company='Company A', Title='head of department', Email='head1@test.com'),
            new Lead(FirstName='Test', LastName='Exec', Company='Company A', Title='exec', Email='exec@test.com'),
            new Lead(FirstName='Test', LastName='Chief', Company='Company A', Title='chief', Email='chief@test.com'),
            new Lead(FirstName='Test', LastName='Head', Company='Company A', Title='head', Email='head2@test.com'),
            new Lead(FirstName='Test', LastName='Assist', Company='Company A', Title='assist', Email='assist@test.com'),
            new Lead(FirstName='Test', LastName='Deputy', Company='Company A', Title='deputy', Email='deputy@test.com'),
            new Lead(FirstName='Test', LastName='Junior', Company='Company A', Title='jr', Email='jr@test.com')
        };

        Test.startTest();
        insert testLeads;
        Test.stopTest();
            
        Map<String, String> expectedTitles = new Map<String, String>{
            'vp1@test.com' => 'Vice President',
            'vp2@test.com' => 'Vice President',
            'vp3@test.com' => 'Vice President',
            'mgr@test.com' => 'Manager',
            'mgr2@test.com' => 'Manager',
            'head1@test.com' => 'Manager',
            'exec@test.com' => 'Executive',
            'chief@test.com' => 'Executive',
            'head2@test.com' => 'Executive',
            'assist@test.com' => 'Assistant',
            'deputy@test.com' => 'Assistant',
            'jr@test.com' => 'Assistant'
        };
        
        for (Lead l : [SELECT Email, Title FROM Lead WHERE Email IN :expectedTitles.KeySet()]) {
            System.assertEquals(expectedTitles.get(l.email), l.Title, 'Title normalization failed for ' + l.Email);
        }
    }

    @isTest
    static void testHandleNoTitleNormalization() {
        Lead lead = createTestLead('normalize@test.com', 'sales associate', 'Test Company', false);
        Test.startTest();
        insert lead;
        Test.stopTest();

        Lead updatedLead = [SELECT Title FROM Lead WHERE Id = :lead.Id];
        System.assertEquals('sales associate', updatedLead.Title, 'Title should be' + updatedlead.Title);
    }

    @isTest 
    static void testHandleLeadAutoConvertSingleMatch() {
        // Create a contact with an email that will match the Lead's
        Account acc = new Account(Name='Test Account');
        insert acc;
        Contact c = new Contact( 
            FirstName = 'Match',
            LastName = 'Contact',
            Email = 'convertme@test.com',
            AccountId = acc.Id
        );
    insert c;

    Lead lead = createTestLead('convertme@test.com', 'Director', 'Test Company', true);
    Test.startTest();
    update lead;
    Test.stopTest();

    Lead convertedLead = [SELECT IsConverted, ConvertedContactId FROM Lead Where Id = :lead.Id];
    System.assertEquals(true, convertedLead.IsConverted, 'The lead was not converted.');
    System.assertEquals(c.Id, convertedLead.ConvertedContactId, 'The lead should have converted to the matching contact.');
}

    @isTest 
    static void testHandleLeadAutoConvertMultipleMatches() {
        // Insert two contacts with the same email
        Account acc = new Account(Name = 'Dup Contacts Co');
        insert acc;

        Contact c1 = new Contact(FirstName = 'Contact1', LastName = 'Dup', Email = 'duplicate@test.com', AccountId = acc.Id);
        Contact c2 = new Contact(FirstName = 'Contact2', LastName = 'Dup', Email = 'duplicate@test.com', AccountId = acc.Id);
        insert new List<Contact>{c1, c2};

        Lead lead = createTestLead('duplicate@test.com', 'VP', 'Dup Company', true);
        Test.startTest();
        update lead;
        Test.stopTest();

        Lead unconvertedLead = [SELECT IsConverted FROM Lead WHERE Id = :lead.id];
        System.assertEquals(false, unconvertedLead.IsConverted, 'The lead should not be converted due to multiple matching contatcts.');
    }

    @isTest 
    static void testHandleAutoLeadScoring() {
        Lead lead = createTestLead('score@test.com', 'Manager', 'Important Co', false);
        Test.startTest();
        insert lead;
        Test.stopTest();

        Lead updatedLead = [SELECT Lead_Score__c FROM Lead WHERE Id = :lead.Id];
        System.assertNotEquals(null, updatedLead.Lead_Score__c, 'Lead score should be populated.');
    }

    @isTest
static void testAutoLeadScoringVariants() {
    // Creating test leads for various conditions
    List<Lead> leads = new List<Lead>{
        new Lead(FirstName='Web', LastName='Lead', Company='Web Co', Email='web@test.com', LeadSource='Website', Phone='1234567890'),
        new Lead(FirstName='Phone', LastName='Lead', Company='Phone Co', Email='phone@test.com', LeadSource='Phone Inquiry', Phone='0987654321'),
        new Lead(FirstName='Tech', LastName='Lead', Company='Tech Co', Email='tech@test.com', Industry='Technology'),
        new Lead(FirstName='No Source', LastName='Lead', Company='No Source Co', Email='nosource@test.com'),
        new Lead(FirstName='Website Only', LastName='Lead', Company='Website Only Co', Email='websiteonly@test.com', LeadSource='Website'),
        new Lead(FirstName='Phone Only', LastName='Lead', Company='Phone Only Co', Email='phoneonly@test.com', Phone='9876543210'),
        new Lead(FirstName='Tech Only', LastName='Lead', Company='Tech Only Co', Email='techonly@test.com', Industry='Technology')
    };
    insert leads;

    // Create a map of expected scores based on the conditions
    Map<String, Integer> expectedScores = new Map<String, Integer>{
        'web@test.com' => 8, // Website (3) + Phone (5)
        'phone@test.com' => 5, // Phone (5) - no website or industry
        'tech@test.com' => 10, // Industry 'Technology' (10) - no website or phone
        'nosource@test.com' => 0, // No scoring criteria met
        'websiteonly@test.com' => 3, // Website (3) - no phone or industry
        'phoneonly@test.com' => 5, // Phone (5) - no website or industry
        'techonly@test.com' => 10 // Industry 'Technology' (10) - no website or phone
    };

    // Call the method to process the scores
    Test.startTest();
    LeadTriggerHandler.handleAutoLeadScoring([SELECT Id, Email, Lead_Score__c FROM Lead WHERE Email IN :expectedScores.keySet()]);
    Test.stopTest();

    // Assert that the actual scores match the expected scores
    for (Lead l : [SELECT Email, Lead_Score__c FROM Lead WHERE Email IN :expectedScores.keySet()]) {
        System.assertEquals(expectedScores.get(l.Email), l.Lead_Score__c,
            'Lead score for ' + l.Email + ' should match the expected score.');
    }
}
}