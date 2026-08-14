public with sharing class PolicyUiStrategy {

    public interface IPolicyUiStrategy {
        BindProcessController.PolicyUiDto buildDto(Policy_Information__c pol, PolicyContext ctx);
    }

    public class PolicyStrategyFactory {
        public IPolicyUiStrategy getStrategy(PolicyState state) {
            switch on state {
                when REFUNDED { return new RefundedStrategy(); }
                when REFUND_DUE { return new RefundDueStrategy(); }
                when FULLY_PAID { return new FullyPaidStrategy(); }
                when APPLY_CREDIT_ELIGIBLE { return new ApplyCreditStrategy(); }
                when PAYMENT_DUE { return new PaymentDueStrategy(); }
                when else { return new NoFeeInactiveStrategy(); }
            }
        }
    }

    public class RefundedStrategy implements IPolicyUiStrategy {
        public BindProcessController.PolicyUiDto buildDto(Policy_Information__c pol, PolicyContext ctx) {
            BindProcessController.PolicyUiDto dto = new BindProcessController.PolicyUiDto();
            dto.policy = pol;
            dto.isPathwayNoFee = true;
            dto.tileStatus = 'Refunded';
            dto.tileActionText = 'None';
            dto.feeAmountFormatted = '$' + ctx.refundableBalance.setScale(2);
            dto.tileStatusColor = '#64748b';
            dto.hasTileAction = false;

            dto.modalStatusText = 'Refunded';
            dto.modalActionText = 'View Details';
            dto.modalStatusPillClass = 'pill-blue';
            dto.modalActionBtnClass = 'btn-white-blue';
            dto.hasPaymentLink = true;
            dto.isActionDisabled = false;
            return dto;
        }
    }

    public class RefundDueStrategy implements IPolicyUiStrategy {
        public BindProcessController.PolicyUiDto buildDto(Policy_Information__c pol, PolicyContext ctx) {
            BindProcessController.PolicyUiDto dto = new BindProcessController.PolicyUiDto();
            dto.policy = pol;
            dto.isPathwayIssueRefund = true;
            dto.tileStatus = 'Refund Due';
            dto.tileActionText = 'Issue Refund';
            dto.feeAmountFormatted = '$' + ctx.feeAmount.setScale(2);
            dto.tileStatusColor = '#e28705';
            dto.hasTileAction = true;

            dto.modalStatusText = 'Paid';
            dto.modalActionText = 'Issue Refund';
            dto.modalStatusPillClass = 'pill-green';
            dto.modalActionBtnClass = 'btn-orange-filled';
            dto.hasPaymentLink = true;
            return dto;
        }
    }

    public class FullyPaidStrategy implements IPolicyUiStrategy {
        public BindProcessController.PolicyUiDto buildDto(Policy_Information__c pol, PolicyContext ctx) {
            BindProcessController.PolicyUiDto dto = new BindProcessController.PolicyUiDto();
            dto.policy = pol;
            dto.isPathwayCollectFee = true;
            dto.tileStatus = 'Paid';
            dto.tileActionText = 'None';
            dto.feeAmountFormatted = '$' + ctx.feeAmount.setScale(2);
            dto.tileStatusColor = '#166534';
            dto.hasTileAction = false;

            dto.modalStatusText = 'Paid';
            dto.modalActionText = 'View Details';
            dto.modalStatusPillClass = 'pill-green';
            dto.modalActionBtnClass = 'btn-white-blue';
            dto.hasPaymentLink = true;
            return dto;
        }
    }

    public class ApplyCreditStrategy implements IPolicyUiStrategy {
        public BindProcessController.PolicyUiDto buildDto(Policy_Information__c pol, PolicyContext ctx) {
            BindProcessController.PolicyUiDto dto = new BindProcessController.PolicyUiDto();
            dto.policy = pol;
            dto.isPathwayApplyCredit = true;
            dto.tileStatus = 'Available Credit';
            dto.tileActionText = 'Apply Credit';
            dto.feeAmountFormatted = '$' + ctx.feeAmount.setScale(2);
            dto.tileStatusColor = '#8b5cf6';
            dto.hasTileAction = true;

            dto.modalStatusText = 'Not Sent';
            dto.modalActionText = 'Apply Credit';
            dto.modalStatusPillClass = 'pill-gray';
            dto.modalActionBtnClass = 'btn-purple-filled';
            dto.hasPaymentLink = true;
            return dto;
        }
    }

    public class PaymentDueStrategy implements IPolicyUiStrategy {
        public BindProcessController.PolicyUiDto buildDto(Policy_Information__c pol, PolicyContext ctx) {
            BindProcessController.PolicyUiDto dto = new BindProcessController.PolicyUiDto();
            dto.policy = pol;
            Decimal remaining = ctx.feeAmount - ctx.creditApplied;
            if (ctx.creditApplied > 0) {
                dto.isPathwayCollectFee = true;
                dto.tileStatus = 'Balance Due';
                dto.tileActionText = 'Process Payment';
                dto.feeAmountFormatted = '$' + remaining.setScale(2);
                dto.tileStatusColor = '#0176d3';
                dto.hasTileAction = true;

                dto.modalStatusText = 'Not Sent';
                dto.modalActionText = 'Send Payment Link';
                dto.modalStatusPillClass = 'pill-gray';
                dto.modalActionBtnClass = 'btn-blue-filled';
                dto.hasPaymentLink = true;
            } else {
                dto.isPathwayCollectFee = true;
                dto.tileStatus = 'Balance Due';
                dto.tileActionText = 'Process Payment';
                dto.feeAmountFormatted = '$' + ctx.feeAmount.setScale(2);
                dto.tileStatusColor = '#0176d3';
                dto.hasTileAction = true;

                dto.modalStatusText = 'Not Sent';
                dto.modalActionText = 'Send Payment Link';
                dto.modalStatusPillClass = 'pill-gray';
                dto.modalActionBtnClass = 'btn-blue-filled';
                dto.hasPaymentLink = true;
            }
            return dto;
        }
    }

    public class NoFeeInactiveStrategy implements IPolicyUiStrategy {
        public BindProcessController.PolicyUiDto buildDto(Policy_Information__c pol, PolicyContext ctx) {
            BindProcessController.PolicyUiDto dto = new BindProcessController.PolicyUiDto();
            dto.policy = pol;
            dto.isPathwayNoFee = true;
            dto.tileStatus = 'Not Applicable';
            dto.tileActionText = 'None';
            dto.feeAmountFormatted = '$0.00';
            dto.tileStatusColor = '#64748b';
            dto.hasTileAction = false;

            dto.modalStatusText = 'Not Applicable';
            dto.modalActionText = 'Not Applicable';
            dto.modalStatusPillClass = 'pill-gray-disabled';
            dto.modalActionBtnClass = 'btn-white-blue';
            dto.isActionDisabled = true;
            return dto;
        }
    }
}