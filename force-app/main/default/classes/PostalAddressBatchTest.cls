/***********************************************************************************************************
 * Name             : PostalAddressBatchTest
 * Created By       : Vicky Weissman
 * Created Date     : April 2019
 * Purpose          : validate PostalAddressBatch.apxt 
 * 
 * Abbreviations
 * H = Household, C = Contact, Addr = Postal Address
 * 
 * Notes:  
 * - Running out of time, will at least get started
 * 
***********************************************************************************************************/
@istest
public class PostalAddressBatchTest {
    /***********************************************************************************************************
     * quickTest
     * Running a quick test in the very little time remaining
     * I'm getting too hackey. Stopping.
     ***********************************************************************************************************/ 
/*
     static TestMethod void quickTest() {  
        // make a contact and household
        list<contact> l_contact = new list<contact>();
        contact Lisa = PostalAddressHandlerTest.makeContact('Lisa', 'Simpson', '123 Main Street', 'Springfield', 'Oregon');
        l_contact.add(Lisa);
        insert(Lisa);
        
        // make a list of addresses that will mock the query output
        account SimpsonH = [Select id
                            From account
                            Where Name like '%Simpson%'
                            Limit 1];
        
        Postal_Address__c addrInRange = PostalAddressHandlerTest.makePostalAddress(SimpsonH.id, (date.today()).addDays(-2), date.today(), '321 Almost Done', 'Paradise City', 'Indiana');    
        list<sobject> l_mockQueryResult = new list<sobject>();
        l_mockQueryResult.add(addrInRange);
        
        // run the batch job
        test.startTest();
        PostalAddressBatch job = new PostalAddressBatch(l_mockQueryResult);
        database.executeBatch(job);
        test.stopTest();
*/        
     
} // end PostalAddressBatchTest class