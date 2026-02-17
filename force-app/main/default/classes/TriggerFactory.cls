public class TriggerFactory {
    private static Set<Type> bypassHandlerSet = new Set<Type>();

    public static void bypass(Type t) { bypassHandlerSet.add(t); } public static void clearBypass() { bypassHandlerSet.clear(); }

    public static void createAndExcuteHandler(Type vType) {
        if (bypassHandlerSet.contains(vType)) return;
        TriggerInterface handler = (TriggerInterface) vType.newInstance();
        execute(handler);
    }

    private static void execute(TriggerInterface handler) {
        if (Trigger.isBefore) {
            if (Trigger.isInsert) {
                handler.beforeInsert(Trigger.new);
            } else if (Trigger.isUpdate) {
                handler.beforeUpdate(Trigger.newMap, Trigger.oldMap);
            } else if (Trigger.isDelete) {
                handler.beforeDelete(Trigger.oldMap);
            }
        } else {
            if (Trigger.isInsert) {
                handler.afterInsert(Trigger.newMap);
            } else if (Trigger.isUpdate) {
                handler.afterUpdate(Trigger.newMap, Trigger.oldMap);
            } else if (Trigger.isDelete) {
                handler.afterDelete(Trigger.oldMap);
            } else if (Trigger.isUndelete) {
                handler.afterUnDelete(Trigger.newMap);
            }
        }
    }
}