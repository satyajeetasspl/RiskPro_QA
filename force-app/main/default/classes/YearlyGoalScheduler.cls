public class YearlyGoalScheduler implements Schedulable {
    public void execute(SchedulableContext SC) {
        YearlyGoalRolloverBatch batchJob = new YearlyGoalRolloverBatch();
        Database.executeBatch(batchJob, 200); 
    }
}