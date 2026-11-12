#define OnInit ProductionOnInit
#define OnTick ProductionOnTick
#define OnDeinit ProductionOnDeinit
#include "..\\StaticGridBot v4.06.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit

int stage=0, checks=0, failures=0;
bool harnessInitialized=false;
void Check(bool okay,string label)
{
    checks++;
    if(!okay) { failures++; Print("FAIL ",label); }
}
int OnInit()
{
    if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;
    Print("V405_TESTER_START account_mode=",AccountInfoInteger(ACCOUNT_MARGIN_MODE));
    if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
        return INIT_FAILED;
    ConfigureRegions(); InitializeStateNames();
    harnessInitialized=true;
    trade.SetMarginMode(); trade.SetTypeFillingBySymbol(_Symbol);
    GlobalStartPrice=-1;
    return INIT_SUCCEEDED;
}
void OnTick()
{
    double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
    double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
    if(stage==0)
    {
        for(int r=0;r<3;r++)
        {
            regions[r].enabled=true; regions[r].top=ask+1000*_Point;
            regions[r].bottom=bid-2000*_Point; regions[r].points=100;
            regions[r].takeProfit=500; regions[r].levels=4; regions[r].lot=(r+1)*0.01;
        }
        ManageGridOrders();
        for(int r=0;r<3;r++)
        {
            int count=0;
            for(int i=0;i<OrdersTotal();i++)
                if(OrderGetTicket(i)>0 && OrderGetInteger(ORDER_MAGIC)==regions[r].magic) count++;
            Check(count>0,"each overlap region has pending orders");
        }
        regions[1].enabled=false;
        ManageGridOrders();
        for(int i=0;i<OrdersTotal();i++)
            if(OrderGetTicket(i)>0) Check(OrderGetInteger(ORDER_MAGIC)!=regions[1].magic,"disabled pending removed");
        DeleteAllEAPendingOrders();
        for(int r=0;r<3;r++)
        {
            trade.SetExpertMagicNumber(regions[r].magic);
            Check(ConfirmTradeResult(trade.Buy(0.01,_Symbol,ask,0,ask+1000*_Point),"test buy",0),"first fragment");
            Check(ConfirmTradeResult(trade.Buy(0.02,_Symbol,ask,0,ask+1500*_Point),"test buy",0),"second fragment");
        }
        for(int i=0;i<PositionsTotal();i++)
            if(PositionGetTicket(i)>0) RememberDenseTarget();
        for(int r=0;r<3;r++) { regions[r].lot=0.03; regions[r].takeProfit=10; }
        DynamicTPUpdater();
        for(int i=0;i<PositionsTotal();i++)
        {
            if(PositionGetTicket(i)==0) continue;
            Check(MathAbs(PositionGetDouble(POSITION_TP)-RememberDenseTarget())<=_Point*0.5,"old target survives parameters");
        }
        for(int r=0;r<3;r++) StartMergePlan(regions[r].magic,regions[r].mergedMagic);
        stage=1;
    }
    else if(stage==1)
    {
        ProcessPendingMergePlans();
        bool pending=false;
        for(int r=0;r<3;r++) if(HasPendingMerge(regions[r].magic)) pending=true;
        if(pending) return;
        for(int r=0;r<3;r++)
        {
            int count=0;
            for(int i=0;i<PositionsTotal();i++)
            {
                ulong ticket=PositionGetTicket(i);
                if(ticket==0 || PositionGetInteger(POSITION_MAGIC)!=regions[r].mergedMagic) continue;
                count++;
                Check(MathAbs(PositionGetDouble(POSITION_VOLUME)-0.03)<1e-8,"mixed lot merge volume");
                long id=PositionGetInteger(POSITION_IDENTIFIER);
                Check(HasActiveMergeState(regions[r].mergedMagic,id),"merged state bound");
                Check((int)ReadMergeState(MergeActiveKey(regions[r].mergedMagic,id,"C"),0)==2,"two original rungs");
                double first=ReadMergeState(MergeActiveUnitKey(regions[r].mergedMagic,id,0,"T"),0);
                ProcessOneMergedBatchSplit(ticket,regions[r].mergedMagic,id,first);
                Check(PositionSelectByTicket(ticket) &&
                      MathAbs(PositionGetDouble(POSITION_VOLUME)-0.02)<1e-8,"first rung original lot");
                double last=ReadMergeState(MergeActiveUnitKey(regions[r].mergedMagic,id,1,"T"),0);
                ProcessOneMergedBatchSplit(ticket,regions[r].mergedMagic,id,last);
                Check(!PositionSelectByTicket(ticket),"last rung closes remainder");
            }
            Check(count==1,"one merged position per region including disabled");
        }
        stage=2;
        PrintFormat("V405_TESTER_RESULT checks=%d failures=%d",checks,failures);
        TesterStop();
    }
}
void OnDeinit(const int reason)
{
    if(!harnessInitialized) return;
    if(stage!=2) Print("V405_TESTER_INCOMPLETE stage=",stage);
    ClearCycleState();
    ProductionOnDeinit(reason);
}
