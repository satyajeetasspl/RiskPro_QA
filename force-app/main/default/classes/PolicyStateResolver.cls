public with sharing class PolicyStateResolver {

    public static PolicyState resolve(PolicyContext ctx) {
        if (ctx == null) return PolicyState.NO_FEE_INACTIVE;

        if (ctx.isRefunded) {
            return PolicyState.REFUNDED;
        }
        if (ctx.isAbandoned && ctx.refundableBalance > 0) {
            return PolicyState.REFUND_DUE;
        }
        if (ctx.isReplaced && ctx.isPaid && ctx.refundableBalance > 0 && !ctx.hasPendingCreditReplacement) {
            return PolicyState.REFUND_DUE;
        }
        if (ctx.isPaid || (ctx.creditApplied >= ctx.feeAmount && ctx.feeAmount > 0)) {
            return PolicyState.FULLY_PAID;
        }
        if (ctx.isReplaced && ctx.isPaid) {
            return PolicyState.FULLY_PAID;
        }
        if (ctx.feeAmount == 0) {
            return PolicyState.NO_FEE_INACTIVE;
        }
        if (ctx.isAbandoned && ctx.refundableBalance == 0) {
            return PolicyState.NO_FEE_INACTIVE;
        }
        if (ctx.globalAvailableCredit > 0 && ctx.feeAmount > 0 && !ctx.isPaid && ctx.creditApplied < ctx.feeAmount) {
            return PolicyState.APPLY_CREDIT_ELIGIBLE;
        }
        if (ctx.feeAmount > 0 && !ctx.isPaid && !ctx.isAbandoned) {
            return PolicyState.PAYMENT_DUE;
        }

        return PolicyState.NO_FEE_INACTIVE;
    }
}