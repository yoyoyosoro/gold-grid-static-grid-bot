double testPoint = 0.001;
int testDigits = 3;
#define _Point testPoint
#define _Digits testDigits
#define OnInit ProductionOnInit
#define OnTick ProductionOnTick
#define OnDeinit ProductionOnDeinit
#define OnTimer ProductionOnTimer
#define OnChartEvent ProductionOnChartEvent
#include "..\\StaticGridBot v4.08.mq5"
#undef OnChartEvent
#undef OnInit
#undef OnTick
#undef OnDeinit
#undef OnTimer

int checks = 0, failures = 0;
string report = "";
void Check(bool okay, string label)
{
    checks++;
    if(okay) return;
    failures++;
    report += "FAIL " + label + "\n";
    Print("FAIL ", label);
}
void Near(double actual, double expected, string label)
{
    Check(MathAbs(actual - expected) <= 1e-8 * MathMax(1.0, MathAbs(expected)), label);
}
void SetRegion(int r, double bottom, double top, int points, double lot)
{
    regions[r].enabled = true;
    regions[r].bottom = bottom; regions[r].top = top;
    regions[r].points = points; regions[r].lot = lot;
}
void BruteRange(double bottom, double top, int points, double lot, double offset,
                double &volume, double &cost)
{
    volume = 0; cost = 0;
    for(int k = -1000; k <= 1000; k++)
    {
        double price = NormalizeDouble(k * points * testPoint + offset, testDigits);
        if(price < bottom || price >= top) continue;
        volume += lot; cost += price * lot;
    }
}
void TestRanges()
{
    for(int digits = 2; digits <= 5; digits++)
    {
        testDigits = digits; testPoint = MathPow(10.0, -digits);
        for(int points = 1; points <= 17; points += 4)
        for(int offset = -19; offset <= 19; offset += 19)
        for(int edge = 0; edge < 7; edge++)
        {
            double bottom = (13 + edge * 0.25) * testPoint;
            double top = (67 - edge * 0.25) * testPoint;
            double v, c, bv, bc;
            Check(GridRangeTotals(bottom, top, points, 0.03, offset * testPoint, v, c), "range valid");
            BruteRange(bottom, top, points, 0.03, offset * testPoint, bv, bc);
            Near(v, bv, "range count"); Near(c, bc, "range cost");
        }
    }
    testDigits = 3; testPoint = 0.001;
    double v,c;
    Check(GridRangeTotals(2, 1, 1, 0.01, 0, v, c) && v == 0, "empty range");
    Check(!GridRangeTotals(1, 2, 0, 0.01, 0, v, c), "invalid spacing");
}
void TestCandidates()
{
    ConfigureRegions();
    for(int digits = 2; digits <= 5; digits++)
    {
        testDigits = digits; testPoint = MathPow(10.0, -digits);
        SetRegion(0, 10 * testPoint, 700 * testPoint, 17, 0.01);
        for(int quote = 10; quote < 1000; quote += 7)
        for(int j = 1; j <= 23; j++)
        {
            double ask = quote * testPoint + 0.3 * testPoint;
            double step = regions[0].points * testPoint;
            double oldPrice = NormalizeDouble(MathFloor(ask / step) * step - j * step +
                                               InpOffsetPoints * testPoint, testDigits);
            double price = DenseCandidatePrice(0, ask, j);
            Near(price, oldPrice, "v404 candidate");
            bool oldAllowed = !(oldPrice >= regions[0].top - 0.001 ||
                                oldPrice < regions[0].bottom || ask - oldPrice < step);
            Check(DenseCandidateAllowed(0, ask, price) == oldAllowed, "v404 eligibility");
        }
    }
    testDigits = 3; testPoint = 0.001;
    SetRegion(0, 1, 2, 10, 0.01);
    Check(DensePriceAllowed(0, 1), "bottom inclusive");
    Check(!DensePriceAllowed(0, 1.999), "top tolerance exclusive");
    Check(!DensePriceAllowed(0, 0.999), "below bottom excluded");
    SetRegion(1, 1, 2, 10, 0.03);
    Check(DenseCandidateAllowed(0, 1.8, 1.5) && DenseCandidateAllowed(1, 1.8, 1.5), "overlap independent");
    regions[0].enabled = false;
    Check(!DenseCandidateAllowed(0, 1.8, 1.5) && DenseCandidateAllowed(1, 1.8, 1.5), "disabled independent");
}
void TestAggregation()
{
    ConfigureRegions(); GlobalStartPrice = -1;
    SetRegion(0, 1, 1.051, 10, 0.01);
    SetRegion(1, 1.02, 1.061, 20, 0.03);
    SetRegion(2, 1.09, 1.141, 25, 0.02);
    int points[3]; double expectedV = 0, expectedC = 0;
    for(int r = 0; r < 3; r++)
    {
        points[r] = regions[r].points;
        double v,c;
        BruteRange(regions[r].bottom, regions[r].top - 0.001, points[r], regions[r].lot,
                   InpOffsetPoints * testPoint, v, c);
        expectedV += v; expectedC += c;
    }
    double actualV,actualC;
    Check(FullGridTotals(points, actualV, actualC), "full valid");
    Near(actualV, expectedV, "overlap gap volume"); Near(actualC, expectedC, "overlap gap cost");
    Near(LowestEnabledBottom(), 1, "lowest bottom");
    for(int r = 0; r < 3; r++) regions[r].enabled = false;
    Check(FullGridTotals(points, actualV, actualC) && actualV == 0 && actualC == 0, "all disabled totals");
    Near(LowestEnabledBottom(), 0, "all disabled bottom");
}
void TestDensity()
{
    ConfigureRegions();
    int originals[3] = {2,5,7};
    for(int r=0;r<3;r++)
    {
        regions[r].enabled=true; regions[r].points=originals[r];
        densityPoints[r]=1; densityLimit[r]= r==0 ? 3 : 30;
    }
    densityStatus=0;
    for(int iteration=0;iteration<40;iteration++)
    {
        double next=1e100;
        for(int r=0;r<3;r++)
            if(densityPoints[r]<densityLimit[r])
                next=MathMin(next,(double)densityPoints[r]/originals[r]);
        if(next==1e100) { Check(!AdvanceDensityCandidate(),"density terminal"); break; }
        int expected[3];
        for(int r=0;r<3;r++) expected[r]=(int)MathFloor(originals[r]*(next+1e-9))+1;
        Check(AdvanceDensityCandidate(),"density advances");
        for(int r=0;r<3;r++) Check(densityPoints[r]==expected[r],"common scale including stable range");
    }
}
void TestIdentityAndState()
{
    ConfigureRegions();
    for(int r=0;r<3;r++)
    {
        Check(RegionForMagic(regions[r].magic)==r && IsDenseSourceMagic(regions[r].magic),"source owner");
        Check(RegionForMagic(regions[r].mergedMagic)==r && IsDenseMergedMagic(regions[r].mergedMagic),"merged owner");
    }
    Check(RegionForMagic(InpBaseMagic)==-1 && RegionForMagic(InpBaseGridMagic)==-1,"base isolation");
    Check(regions[0].magic==InpDownMagic && regions[0].mergedMagic==InpDownMergedMagic,"legacy identities");
    string prefix="TEST405_"+IntegerToString((long)GetTickCount64())+"_";
    regionStatePrefix=prefix;
    gvDenseSliceName=prefix+"legacyD"; gvUpperSliceName=prefix+"legacyU";
    for(int r=0;r<3;r++) regions[r].stateKey=prefix+IntegerToString(r)+"_";
    GlobalVariableSet(gvDenseSliceName,123);
    LoadRegionSlices(4500);
    Check(regions[0].sliceLevel==123,"legacy slice restoration");
    regions[1].sliceLevel=456; SaveRegionSlice(1);
    LoadRegionSlices(4501);
    Check(regions[0].sliceLevel==123 && regions[1].sliceLevel==456,"separate restart watermarks");
    regions[0].points=600;
    LoadRegionSlices(4501);
    Check(regions[0].sliceLevel==(int)MathFloor((4501-InpOffsetPoints*testPoint)/(600*testPoint)),
          "changed geometry rebased");
    regions[1].points=1; regions[1].top=1;
    LoadRegionSlices(4501);
    Check(regions[1].points==InpDown2GridPoints && regions[1].sliceLevel==456,"disabled management restored");
    GlobalVariablesDeleteAll(prefix);
}
void TestLines()
{
    ConfigureRegions(); GlobalStartPrice=-1;
    linePrefix="TEST405_LINE_";
    SetRegion(0,1,2,10,0.01); SetRegion(1,1,2,20,0.02); SetRegion(2,2,3,30,0.03);
    UpdateRegionLines();
    for(int r=0;r<3;r++)
    {
        string name=linePrefix+IntegerToString(r+1)+"_Top";
        Check(ObjectFind(0,name)>=0,"line created");
        Near(ObjectGetDouble(0,name,OBJPROP_PRICE),regions[r].top,"line price");
        Check(!ObjectGetInteger(0,name,OBJPROP_SELECTABLE),"line immutable");
    }
    regions[1].enabled=false; UpdateRegionLines();
    Check(ObjectFind(0,linePrefix+"2_Top")<0 && ObjectFind(0,linePrefix+"2_Bottom")<0,"disabled removes lines");
    Check(ObjectFind(0,linePrefix+"1_Top")>=0 && ObjectFind(0,linePrefix+"3_Top")>=0,"other lines retained");
    regions[0].top=0; GlobalStartPrice=1.25;
    regions[0].style=STYLE_SOLID; regions[0].width=3;
    UpdateRegionLines();
    Near(ObjectGetDouble(0,linePrefix+"1_Top",OBJPROP_PRICE),GetBaseAnchor(),"smart top follows anchor");
    Check(ObjectGetInteger(0,linePrefix+"1_Top",OBJPROP_WIDTH)==3,"solid width honored");
    regions[0].style=STYLE_DASH;
    UpdateRegionLines();
    Check(ObjectGetInteger(0,linePrefix+"1_Top",OBJPROP_WIDTH)==1,"native dash uses one pixel");
    ObjectsDeleteAll(0,linePrefix);
}
void TestRiskAndSolver()
{
    ConfigureRegions();
    testPoint=1; testDigits=0; GlobalStartPrice=-1;
    cachedRiskDataValid=true; cachedReferenceLot=0.01;
    cachedMarginPerLot=0; cachedProfitPerLot=100; cachedBasePrice=3000;
    Near(EstimateMargin(1,3000),0,"zero margin valid");
    Near(EstimateProfit(0.03,3010,3000),-30,"profit actual volume");
    Check(!PsychologicalFeasible(0.01,30.10,10,ACCOUNT_STOPOUT_MODE_PERCENT,50),"equity at zero not feasible");
    Check(PsychologicalFeasible(0.01,30.10,11,ACCOUNT_STOPOUT_MODE_PERCENT,50),"zero margin equity positive feasible");
    Check(!PsychologicalFeasible(0.01,30.10,60,ACCOUNT_STOPOUT_MODE_MONEY,50),"money stopout equality excluded");
    cachedMarginPerLot=1000;
    Check(!PsychologicalFeasible(0.01,30.10,15,ACCOUNT_STOPOUT_MODE_PERCENT,100),"margin requirement included");
    cachedMarginPerLot=0;
    SetRegion(0,3010,3021,2,0.01);
    SetRegion(1,3015,3026,5,0.02);
    SetRegion(2,3030,3041,7,0.03);
    double events[];
    ArrayResize(events,3*500);
    for(int r=0;r<3;r++)
        for(int k=1;k<=500;k++) events[r*500+k-1]=(double)k/regions[r].points;
    ArraySort(events);
    for(int scenario=0;scenario<4;scenario++)
    {
        double balance=20*MathPow(5,scenario);
        int expected[3]={1,1,1};
        bool found=false;
        for(int e=-1;e<ArraySize(events);e++)
        {
            double scale=e<0 ? 0.0000001 : events[e]+0.0000001;
            double loss=0;
            for(int r=0;r<3;r++)
            {
                expected[r]=(int)MathCeil(regions[r].points*scale);
                for(int price=(int)regions[r].bottom;price<regions[r].top-0.001;price++)
                    if((price-InpOffsetPoints)%expected[r]==0)
                        loss+=regions[r].lot*(price-InpPsyStopOutLevel)*100;
            }
            if(balance>loss) { found=true; break; }
        }
        Check(found,"independent solver found candidate");
        densitySignature="";
        for(int resume=0;resume<100;resume++)
        {
            DensityResult(balance,ACCOUNT_STOPOUT_MODE_PERCENT,50);
            if(densityStatus!=0) break;
        }
        Check(densityStatus==1,"solver completed");
        for(int r=0;r<3;r++) Check(densityPoints[r]==expected[r],"densest solution matches exhaustive oracle");
    }
    testPoint=0.001; testDigits=3;
}
void TestStateProtection()
{
    ConfigureRegions();
    string prefix="TEST405_P_"+IntegerToString((long)GetTickCount64())+"_";
    gvName=prefix+"start"; legacyGvName=prefix+"old"; gvExitName=prefix+"exit";
    gvUpperSliceName=prefix+"up"; gvDenseSliceName=prefix+"down";
    mergeStateScope=prefix+"merge";
    for(int r=0;r<3;r++) regions[r].stateKey=prefix+IntegerToString(r)+"_";
    targetPrefix=prefix+"target_";
    GlobalVariableSet(MergePlanKey(regions[0].magic,"S"),MERGE_PENDING_OPENING);
    GlobalVariableSet(MergeActiveKey(regions[0].mergedMagic,12345,"C"),2);
    GlobalVariableSet(MergeActiveUnitKey(regions[0].mergedMagic,12345,0,"T"),4500);
    GlobalVariableSet(MergePlanKey(regions[1].magic,"S"),MERGE_PENDING_CLOSING);
    GlobalStartPrice=4400; exitInProgress=false;
    ReconcileStartState();
    Check(HasPendingMerge(regions[0].magic) && HasPendingMerge(regions[1].magic),"anchor reconciliation preserves pending plans");
    Check(HasActiveMergeState(regions[0].mergedMagic,12345),"anchor reconciliation preserves legacy ladder");
    Near(ReadMergeState(MergeActiveUnitKey(regions[0].mergedMagic,12345,0,"T"),0),4500,"legacy target unchanged");
    GlobalStartPrice=4400; exitInProgress=true; GlobalVariableSet(gvExitName,1);
    ReconcileStartState();
    Check(exitInProgress && GlobalVariableCheck(gvExitName),"exit freeze preserved without base position");
    ClearMergePlan(regions[0].magic);
    Check(!HasPendingMerge(regions[0].magic) && HasPendingMerge(regions[1].magic),"clearing plan isolated");
    ClearCycleState();
    Check(!HasPendingMerge(regions[1].magic) && !HasActiveMergeState(regions[0].mergedMagic,12345),"final exit clears managed states");
    GlobalVariablesDeleteAll(prefix);
}

void TestEAExitPrice()
{
    Check(!IsEAExitTriggered(5000, 0), "zero exit price disables full exit");
    Check(!IsEAExitTriggered(4999, 5000), "below exit price keeps trading");
    Check(IsEAExitTriggered(5000, 5000), "touching exit price triggers full exit");
    Check(IsEAExitTriggered(5001, 5000), "above exit price triggers full exit");
}

void TestBaseUpperLimitMode()
{
    Check(!IsBaseUpperLimitValid(0, false), "normal mode requires base upper limit");
    Check(IsBaseUpperLimitValid(0, true), "pure dense mode allows zero base upper limit");
    Check(IsBaseUpperLimitValid(5000, true), "pure dense mode accepts positive base upper limit");
    Check(!IsBaseUpperLimitValid(-1, true), "base upper limit rejects negative value");
}

void TestV407Helpers()
{
    // 安全灯推送：启动后第一个稳定状态只作基线；状态变化需持续 60 秒才算数。
    riskStateCandidate=-1; riskStateNotified=-1; riskStateSince=0;
    UpdateRiskNotification(0,"ok");
    Check(riskStateNotified==-1,"risk first sample only starts timer");
    riskStateSince=TimeLocal()-61; UpdateRiskNotification(0,"ok");
    Check(riskStateNotified==0,"risk baseline set without push");
    UpdateRiskNotification(2,"red");
    Check(riskStateNotified==0,"risk change needs 60s");
    riskStateSince=TimeLocal()-61; UpdateRiskNotification(2,"red");
    Check(riskStateNotified==2,"risk change after 60s recorded");
    UpdateRiskNotification(4,"closed"); riskStateSince=TimeLocal()-61; UpdateRiskNotification(4,"closed");
    Check(riskStateNotified==4,"all regions closed is silent baseline");
    UpdateRiskNotification(0,"ok"); riskStateSince=TimeLocal()-61; UpdateRiskNotification(0,"ok");
    Check(riskStateNotified==0,"leaving closed state rebuilds baseline");
    // 推送冷却：同一 key 在冷却期内只记录一次。
    int before=ArraySize(pushCooldownKeys);
    Notify(false,"testkey",3600,"a"); Notify(false,"testkey",3600,"b");
    Check(ArraySize(pushCooldownKeys)==before+1,"notify cooldown key stored once");
    // 月初、金额显示。
    Check(MonthStartOf(D'2026.11.12 17:30:00')==D'2026.11.01 00:00:00',"month start");
    Check(StringFind(MoneyText(-12.5),"-$")==0,"negative money text");
    // 无持仓时不会误判已有底仓。
    Check(!GuardAgainstDuplicateBase(),"no base position means no duplicate guard");
    // 新增碎单状态与旧状态值不冲突。
    Check(MERGE_FRAGMENT_CLOSE_SENT!=MERGE_FRAGMENT_PENDING && MERGE_FRAGMENT_CLOSE_SENT!=MERGE_FRAGMENT_CLOSED_BY_EA &&
          MERGE_FRAGMENT_CLOSE_SENT!=MERGE_FRAGMENT_CLOSED_AT_TP && MERGE_FRAGMENT_EXCLUDED<0,"fragment states distinct");
    // 状态写入会标记待落盘，落盘后清除。
    stateDirty=false; GVSet("TEST407_DIRTY",1); Check(stateDirty,"state write marks dirty");
    FlushStateNow(); Check(!stateDirty,"flush clears dirty"); GVDel("TEST407_DIRTY");
}

void TestV408Panel()
{
    // 北京交易日：早上 6 点换日。服务器 GMT+2：北京 05:59 = 服务器前一天 23:59，北京 06:00 = 服务器 00:00。
    int off = 2 * 3600;
    Check(BeijingTradingDate(D'2026.11.11 23:59:00', off) == D'2026.11.11 00:00:00', "before 06:00 Beijing is previous day");
    Check(BeijingTradingDate(D'2026.11.12 00:00:00', off) == D'2026.11.12 00:00:00', "06:00 Beijing starts new day");
    Check(BeijingTradingDate(D'2026.11.12 17:30:00', off) == D'2026.11.12 00:00:00', "afternoon same day");
    // 北京 00:30（凌晨美盘）仍算前一天：服务器 GMT+3 时为前一天 19:30。
    Check(BeijingTradingDate(D'2026.11.11 19:30:00', 3 * 3600) == D'2026.11.11 00:00:00', "after midnight before 06:00 counts as previous day");
    Check(BeijingTradingStartServer(D'2026.11.12 00:00:00', off) == D'2026.11.12 00:00:00', "day start server time GMT+2");
    Check(BeijingTradingStartServer(D'2026.11.12 00:00:00', 3 * 3600) == D'2026.11.12 01:00:00', "day start server time GMT+3");
    Check(BeijingTradingStartServer(D'2026.11.12 00:00:00', 0) == D'2026.11.11 22:00:00', "day start server time GMT+0");
    Check(TradingDateLabel(D'2026.11.02 00:00:00') == "11/2", "date label");
    // 合并关碎单从平仓笔数中扣除，最少为 0。
    string key = MergeCloseCounterKey(D'2001.01.01 00:00:00');
    GVDel(key);
    Check(TradesAfterMergeExclusion(12, D'2001.01.01 00:00:00') == 12, "no merge closes keeps count");
    GVSet(key, 30);
    Check(TradesAfterMergeExclusion(42, D'2001.01.01 00:00:00') == 12, "merge closes excluded");
    Check(TradesAfterMergeExclusion(5, D'2001.01.01 00:00:00') == 0, "exclusion never negative");
    GVDel(key);
    // 金额文字与颜色（隔离终端非美分账户，DisplayRate=1）。
    Check(SignedMoneyText(4.12) == "+$4.12", "positive money");
    Check(SignedMoneyText(-23.5) == "-$23.50", "negative money");
    Check(SignedMoneyText(0.001) == "$0.00", "near zero money");
    Check(MoneyColor(1) == PC_GREEN && MoneyColor(-1) == PC_RED && MoneyColor(0) == PC_TEXT, "money colors");
    Check(StopOutText(-5) == "归零不爆仓" && StopOutText(EMPTY_VALUE) == "无法计算", "stop out text");
    Check(DensityValueText("⑦ 最密间距（报价点）：1区 150 / 2区 关闭 / 3区 关闭") == "1区 150 / 2区 关闭 / 3区 关闭", "density value");
    Check(DensityValueText("") == "计算中", "density pending");
    Check(PanelScale() >= 0.6 && PanelScale() <= 3.0, "panel scale in range");
    Check(PanelExpandedHeight() > PB_HEADER, "expanded taller than header");
}

void FillSamplePanel()
{
    panelView.valid = true; panelView.pureDense = true;
    panelView.statusWord = "安全"; panelView.statusDetail = "按当前推演，物理防线内保证金充足"; panelView.statusColor = PC_GREEN;
    panelView.dayLabel = "11/12"; panelView.trades = "27";
    panelView.floating = "-$23.50"; panelView.floatingColor = PC_RED;
    panelView.today = "+$4.12"; panelView.todayColor = PC_GREEN;
    panelView.month = "+$86.37"; panelView.monthColor = PC_GREEN;
    panelView.riskAvailable = true;
    SetRiskRow(0, "占用保证金", "$18.42", "—");
    SetRiskRow(1, "保证金比例", "1284.60%", "—");
    SetRiskRow(2, "触底 4000.000 占用", "$15.10", "$41.88");
    SetRiskRow(3, "触底比例", "412.30%", "168.90%");
    SetRiskRow(4, "爆仓线", "2712.450", "3206.800");
    panelView.defenseLabel = "防线 3000.000 需补充"; panelView.defense = "$0.00 安全通过"; panelView.defenseColor = PC_GREEN;
    panelView.density = "1区 150 / 2区 关闭 / 3区 关闭";
    panelView.posCount[0] = 3; panelView.posVolume[0] = 0.30;
    panelView.posCount[1] = 46; panelView.posVolume[1] = 0.46;
    panelView.posCount[2] = 2; panelView.posVolume[2] = 0.60;
    panelView.posCount[3] = 51; panelView.posVolume[3] = 1.36;
    panelView.swapOpen = "-$3.21"; panelView.swapOpenColor = PC_RED;
    panelView.swapMonth = "-$5.67"; panelView.swapMonthColor = PC_RED;
}

void PanelShots()
{
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    FillSamplePanel();
    panelCollapsed = false; RenderPanel(true); ChartRedraw(); Sleep(800);
    ChartScreenShot(0, "v408-panel-expanded.png", 1100, 760, ALIGN_RIGHT);
    panelCollapsed = true; RenderPanel(true); ChartRedraw(); Sleep(800);
    ChartScreenShot(0, "v408-panel-collapsed.png", 1100, 120, ALIGN_RIGHT);
    PrintFormat("panel scale=%.3f dpi=%d", PanelScale(), TerminalInfoInteger(TERMINAL_SCREEN_DPI));
    DestroyPanel();
}

void OnStart()
{
    if(AccountInfoInteger(ACCOUNT_LOGIN)!=0 ||
       StringFind(TerminalInfoString(TERMINAL_DATA_PATH),"\\tests\\runtime")<0)
    {
        Print("Tests require the isolated tests/runtime terminal with no account.");
        return;
    }
    TestRanges(); TestCandidates(); TestAggregation(); TestDensity(); TestIdentityAndState(); TestLines(); TestRiskAndSolver(); TestStateProtection(); TestEAExitPrice(); TestBaseUpperLimitMode(); TestV407Helpers(); TestV408Panel(); PanelShots();
    report=StringFormat("checks=%d failures=%d\n",checks,failures)+report;
    Print(report);
    int f=FileOpen("v408-results.txt",FILE_WRITE|FILE_TXT|FILE_ANSI);
    if(f!=INVALID_HANDLE) { FileWriteString(f,report); FileClose(f); }
    TerminalClose(failures==0 ? 0 : 1);
}
