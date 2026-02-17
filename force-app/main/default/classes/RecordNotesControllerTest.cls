@IsTest
public class RecordNotesControllerTest {

    @IsTest
    static void testCreateGetUpdateNote() {
        // Create parent record (use Account as sample)
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Test.startTest();

        // CREATE NOTE
        Id noteId = RecordNotesController.createNote(acc.Id, 'Test Title', 'Test Body');

        // GET NOTES
        List<ContentNote> notes = RecordNotesController.getNotes(acc.Id);

        // UPDATE NOTE (only if created)
        if (noteId != null) {
            RecordNotesController.updateNote(noteId, 'Updated Title', 'Updated Body', acc.Id);
        }

        Test.stopTest();
    }

    @IsTest
    static void testCreateNoteWithNullTitleBody() {
        Account acc = new Account(Name = 'Second Account');
        insert acc;

        Test.startTest();

        // Create note with blank values
        Id noteId = RecordNotesController.createNote(acc.Id, null, null);

        // Fetch notes
        List<ContentNote> notes = RecordNotesController.getNotes(acc.Id);

        Test.stopTest();
    }

    @IsTest
    static void testDuplicateCheckFlow() {
        Account acc = new Account(Name = 'Third Account');
        insert acc;

        Test.startTest();

        // First create
        Id firstNoteId = RecordNotesController.createNote(acc.Id, 'Title 1', 'Body 1');

        // Immediate second create to trigger duplicate check
        Id secondNoteId = RecordNotesController.createNote(acc.Id, 'Title 2', 'Body 2');

        // Try update flow
        if (firstNoteId != null) {
            RecordNotesController.updateNote(firstNoteId, 'New Title', 'New Body', acc.Id);
            RecordNotesController.updateNote(firstNoteId, 'New Title Again', 'New Body Again', acc.Id);
        }

        Test.stopTest();
    }

    @IsTest
    static void testGetNotesWithNullRecordId() {
        Test.startTest();
        List<ContentNote> notes = RecordNotesController.getNotes(null);
        Test.stopTest();
    }
}