double testPoint = 0.001;
int testDigits = 3;
#define _Point testPoint
#define _Digits testDigits
#define OnInit ProductionOnInit
#define OnTick ProductionOnTick
#define OnDeinit ProductionOnDeinit
#include "..\\StaticGridBot v4.06.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit

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

void OnStart()
{
    if(AccountInfoInteger(ACCOUNT_LOGIN)!=0 ||
       StringFind(TerminalInfoString(TERMINAL_DATA_PATH),"\\tests\\runtime")<0)
    {
        Print("Tests require the isolated tests/runtime terminal with no account.");
        return;
    }
    TestRanges(); TestCandidates(); TestAggregation(); TestDensity(); TestIdentityAndState(); TestLines(); TestRiskAndSolver(); TestStateProtection(); TestEAExitPrice(); TestBaseUpperLimitMode();
    report=StringFormat("checks=%d failures=%d\n",checks,failures)+report;
    Print(report);
    int f=FileOpen("v405-results.txt",FILE_WRITE|FILE_TXT|FILE_ANSI);
    if(f!=INVALID_HANDLE) { FileWriteString(f,report); FileClose(f); }
    TerminalClose(failures==0 ? 0 : 1);
}
