from models.metric import Metric, CalculationContext, RedoubtMetricImpl


class SmartContractInteractionRedoubtImpl(RedoubtMetricImpl):

    def calculate(self, context: CalculationContext, metric):
        if len(metric.op_codes) > 0:
            op_codes_filter = " OR ".join(map(lambda op: f"op = {op}", metric.op_codes))
        else:
            op_codes_filter = "TRUE"
        if metric.comment_regexp:
            comment_regexp_filter = f"and comment like '{metric.comment_regexp}'"
        else:
            comment_regexp_filter = ""
        return f"""
        select 
                msg_id as id, '{context.project.name}' as project, {0.5 if metric.is_custodial else 1} as weight, 
                source as user_address from messages_local m
        where destination ='{metric.address}' {'and length("comment") > 1' if metric.comment_required else ''} {comment_regexp_filter}
        AND (
            {op_codes_filter}
        )
        """


"""
Simple smart contract interaction - any message (but resulted in successful transaction) to the address provided
"""
class SmartContractInteraction(Metric):
    def __init__(self, description, address, is_custodial=False, comment_required=False, op_codes=[], comment_regexp=None):
        Metric.__init__(self, description, [SmartContractInteractionRedoubtImpl()])
        self.address = address
        self.is_custodial = is_custodial
        self.comment_required = comment_required
        self.op_codes = op_codes
        self.comment_regexp = comment_regexp

