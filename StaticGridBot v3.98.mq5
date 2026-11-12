//+------------------------------------------------------------------+
//|                                          StaticGridBot v3.98.mq5 |
//|                                      Gold Investor Research 专属 |
//|                                      实盘双核版 v3.98             |
//+------------------------------------------------------------------+
#property copyright "Gold Investor Research"
#property link      ""
#property version   "3.98"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// [1] 基础交易与魔术数参数
//====================================================================
input group "=== 1. 基础交易与魔术数参数 ===";
input ulong    InpBaseMagic         = 1;          // 上方底仓系统专属魔术数
input ulong    InpDownMagic         = 2;          // 下方抄底系统专属魔术数
input ulong    InpBaseMergedMagic   = 3;          // 底仓体系合并仓专属魔术数
input ulong    InpDownMergedMagic   = 4;          // 密网体系合并仓专属魔术数
input double   InpMinLot            = 0.01;       // 基础网格与切分单位 (单位: 手)

//====================================================================
// [2] 系统 1：上方底仓系统
//====================================================================
input group "=== 2. 系统 1：上方底仓系统 ===";
input double   InpCustomBasePrice   = 0.0;        // 潜伏狙击点：到达此点位才建底仓 (0为直接开启)
input double   InpBaseUpperLimit    = 0.0;        // 总目标上限；0表示未配置，EA拒绝启动
input bool     InpPureDenseMode     = false;      // true=不建立初始底仓，只运行下方密网
input int      InpBaseGridPoints    = 1000;       // 回补间距（报价点数；距离=点数×_Point，随报价位数自适应）
input int      InpBaseTakeProfit    = 1000;       // 回补单止盈距离（报价点数；距离=点数×_Point）

//====================================================================
// [3] 系统 2：下方密集网格系统
//====================================================================
input group "=== 3. 系统 2：下方密集网格系统 ===";
input double   InpDownUpperLimit    = 0.0;        // 密集网格顶部界限 (设0则智能跟随)
input double   InpDownLowerLimit    = 4000.00;    // 网格铺设下限：仅过滤候选挂单目标价
input int      InpDownGridPoints    = 300;        // 买入间距（报价点数；距离=点数×_Point，随报价位数自适应）
input int      InpDownTakeProfit    = 500;        // 散单止盈距离（报价点数；距离=点数×_Point）
input int      InpMaxGridLevels     = 20;         // 下方动态维持挂单数 (单位: 层数)

//====================================================================
// [4] 风控面板与排版参数 (UI定制)
//====================================================================
input group "=== 4. 风控与面板面板参数 ===";
input double   InpPsyStopOutLevel   = 3000.00;    // 心理防爆仓底线 (用于推演 ⑥ ⑦)
input int      InpPanelX            = 600;        // UI 面板X轴偏移量 (向左推，加大防裁切)
input int      InpPanelY            = 20;         // UI 面板Y轴偏移量 (向下推)
input int      InpPanelFontSize     = 11;         // UI 面板字号大小

//====================================================================
// [5] 其它细节参数
//====================================================================
input group "=== 5. 细节偏移与合并阈值 ===";
input int      InpOffsetPoints      = 0;          // 挂单整数偏移量（报价点数）
input int      InpMergeThreshold    = 30;         // 常规碎单合并阈值
input int      InpEmergencyLimit    = 180;        // 紧急全额合并警戒线

//--- 全局变量 ---
double GlobalStartPrice = 0;       // 0=潜伏, -1=纯密网模式, >0=已确立底仓
string gvName;
string legacyGvName;
string gvUpperSliceName;
string gvDenseSliceName;
string gvExitName;
bool   exitInProgress = false;
static double lastBidLower = 0;
static int    highestSlicedLevelUp = -999999;
static int    lastSlicedLevelDn = -999999;

const int UNINITIALIZED_LEVEL = -999999;
const int MAX_SLICE_ACTIONS_PER_TICK = 20;

//--- 官方引擎静态缓存变量 ---
static double cachedMarginPerLot  = 0;     // 缓存 1 手需要的保证金 (单位: 账户基准)
static double cachedProfitPerLot  = 0;     // 缓存 1 手波动 1 美元的盈亏 (单位: 账户基准)
static double cachedBasePrice     = 0;     // 缓存时的基准价格
static datetime lastCacheUpdateTime = 0;   // 上次缓存更新时间

//+------------------------------------------------------------------+
//| 订单范围、参数校验与持久状态                                    |
//+------------------------------------------------------------------+
bool IsManagedMagic(ulong magic)
{
    return (magic == InpBaseMagic || magic == InpDownMagic ||
            magic == InpBaseMergedMagic || magic == InpDownMergedMagic);
}

bool IsBaseSystemMagic(ulong magic)
{
    return (magic == InpBaseMagic || magic == InpBaseMergedMagic);
}

bool IsMergedMagic(ulong magic)
{
    return (magic == InpBaseMergedMagic || magic == InpDownMergedMagic);
}

double VolumeTolerance()
{
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    return MathMax(0.000001, step * 0.1);
}

bool IsTradeRetcodeSuccessful()
{
    uint code = trade.ResultRetcode();
    return (code == TRADE_RETCODE_DONE || code == TRADE_RETCODE_DONE_PARTIAL ||
            code == TRADE_RETCODE_PLACED || code == TRADE_RETCODE_NO_CHANGES);
}

bool ConfirmTradeResult(bool sent, string action, ulong ticket)
{
    if(sent && IsTradeRetcodeSuccessful()) return true;

    PrintFormat("交易失败：%s，ticket=%I64u，retcode=%u，%s",
                action, ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
    return false;
}

bool RejectInvalidInput(string reason)
{
    Alert("参数错误：", reason, "。EA 未启动，未执行任何删单或交易动作。");
    Print("参数错误：", reason);
    return false;
}

bool ValidateInputs()
{
    if(InpBaseUpperLimit <= 0) return RejectInvalidInput("请填写大于 0 的总目标上限");
    if(InpDownLowerLimit <= 0) return RejectInvalidInput("网格铺设下限必须大于 0");
    if(InpBaseUpperLimit <= InpDownLowerLimit) return RejectInvalidInput("总目标上限必须高于网格铺设下限");
    if(InpDownUpperLimit < 0) return RejectInvalidInput("密网顶部界限不能小于 0");
    if(InpDownUpperLimit > 0 && InpDownUpperLimit <= InpDownLowerLimit)
        return RejectInvalidInput("密网顶部界限必须高于网格铺设下限");
    if(InpCustomBasePrice < 0) return RejectInvalidInput("自定义底仓价格不能小于 0");
    if(InpBaseGridPoints <= 0 || InpDownGridPoints <= 0)
        return RejectInvalidInput("两个网格间距都必须大于 0");
    if(InpBaseTakeProfit <= 0 || InpDownTakeProfit <= 0)
        return RejectInvalidInput("两个止盈点数都必须大于 0");
    if(InpMaxGridLevels <= 0 || InpMergeThreshold <= 0 || InpEmergencyLimit <= 0)
        return RejectInvalidInput("网格层数和合并阈值都必须大于 0");
    if(InpMinLot < 0.01 || MathAbs(InpMinLot * 100.0 - MathRound(InpMinLot * 100.0)) > 0.000001)
        return RejectInvalidInput("最小手数必须不低于 0.01 且按 0.01 递增");

    if(InpBaseMagic == 0 || InpDownMagic == 0 || InpBaseMergedMagic == 0 || InpDownMergedMagic == 0)
        return RejectInvalidInput("四个 Magic 都必须大于 0");
    if(InpBaseMagic == InpDownMagic || InpBaseMagic == InpBaseMergedMagic ||
       InpBaseMagic == InpDownMergedMagic || InpDownMagic == InpBaseMergedMagic ||
       InpDownMagic == InpDownMergedMagic || InpBaseMergedMagic == InpDownMergedMagic)
        return RejectInvalidInput("四个 Magic 不能重复");

    return true;
}

void InitializeStateNames()
{
    legacyGvName = "GoldGrid_StartPrice_" + _Symbol;
    string scope = "GoldGrid_v398_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) +
                   "_" + _Symbol + "_" + IntegerToString((long)InpBaseMagic) +
                   "_" + IntegerToString((long)InpDownMagic) +
                   "_" + IntegerToString((long)InpBaseMergedMagic) +
                   "_" + IntegerToString((long)InpDownMergedMagic);
    gvName             = scope + "_StartPrice";
    gvUpperSliceName   = scope + "_UpperSliceLevel";
    gvDenseSliceName   = scope + "_DenseSliceLevel";
    gvExitName         = scope + "_ExitInProgress";
}

void SaveStartPrice()
{
    GlobalVariableSet(gvName, GlobalStartPrice);
}

void SaveUpperSliceLevel()
{
    GlobalVariableSet(gvUpperSliceName, (double)highestSlicedLevelUp);
}

void SaveDenseSliceLevel()
{
    GlobalVariableSet(gvDenseSliceName, (double)lastSlicedLevelDn);
}

void ClearCycleState()
{
    if(GlobalVariableCheck(gvName)) GlobalVariableDel(gvName);
    if(GlobalVariableCheck(gvUpperSliceName)) GlobalVariableDel(gvUpperSliceName);
    if(GlobalVariableCheck(gvDenseSliceName)) GlobalVariableDel(gvDenseSliceName);
    if(GlobalVariableCheck(gvExitName)) GlobalVariableDel(gvExitName);
    if(GlobalVariableCheck(legacyGvName)) GlobalVariableDel(legacyGvName);

    GlobalStartPrice = 0;
    highestSlicedLevelUp = UNINITIALIZED_LEVEL;
    lastSlicedLevelDn = UNINITIALIZED_LEVEL;
    lastBidLower = 0;
    exitInProgress = false;
}

void LoadCycleState(double bid)
{
    GlobalStartPrice = 0;
    highestSlicedLevelUp = UNINITIALIZED_LEVEL;
    lastSlicedLevelDn = UNINITIALIZED_LEVEL;
    exitInProgress = false;

    if(GlobalVariableCheck(gvName))
    {
        GlobalStartPrice = GlobalVariableGet(gvName);
    }
    else if(GlobalVariableCheck(legacyGvName))
    {
        GlobalStartPrice = GlobalVariableGet(legacyGvName);
        SaveStartPrice();
        GlobalVariableDel(legacyGvName);
        Print("已将 v3.97 起始价便签迁移至 v3.98 的账户与 Magic 隔离状态。");
    }

    if(GlobalVariableCheck(gvUpperSliceName))
        highestSlicedLevelUp = (int)MathRound(GlobalVariableGet(gvUpperSliceName));
    if(GlobalVariableCheck(gvDenseSliceName))
        lastSlicedLevelDn = (int)MathRound(GlobalVariableGet(gvDenseSliceName));
    if(GlobalVariableCheck(gvExitName) && GlobalVariableGet(gvExitName) > 0.5)
        exitInProgress = true;

    double off = (double)InpOffsetPoints * _Point;
    if(GlobalStartPrice > 0 && highestSlicedLevelUp == UNINITIALIZED_LEVEL)
    {
        highestSlicedLevelUp = (int)MathFloor((GlobalStartPrice - off) / ((double)InpBaseGridPoints * _Point));
        SaveUpperSliceLevel();
        Print("未找到上方切分进度，已从底仓起点建立 v3.98 补切基线。");
    }
    if(lastSlicedLevelDn == UNINITIALIZED_LEVEL)
    {
        lastSlicedLevelDn = (int)MathFloor((bid - off) / ((double)InpDownGridPoints * _Point));
        SaveDenseSliceLevel();
    }
    lastBidLower = bid;
}

bool HasBaseSystemPosition()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
           IsBaseSystemMagic(PositionGetInteger(POSITION_MAGIC))) return true;
    }
    return false;
}

double FindActualBaseAnchor()
{
    double candidate = 0;
    long candidateTime = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpBaseMagic)
            continue;

        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        if(GlobalStartPrice > 0 && MathAbs(openPrice - GlobalStartPrice) < 2.0)
            return openPrice;

        if(PositionGetDouble(POSITION_VOLUME) > InpMinLot + VolumeTolerance())
        {
            long openedAt = PositionGetInteger(POSITION_TIME_MSC);
            if(candidate == 0 || openedAt < candidateTime)
            {
                candidate = openPrice;
                candidateTime = openedAt;
            }
        }
    }
    return candidate;
}

void ReconcileStartState()
{
    if(GlobalStartPrice == -1)
    {
        if(!InpPureDenseMode)
        {
            Print("纯密网便签与当前开关不一致，自动清除旧便签并按普通模式重新判定启动条件。");
            ClearCycleState();
        }
        return;
    }
    if(GlobalStartPrice <= 0) return;

    if(!HasBaseSystemPosition())
    {
        Print("未找到与起始价便签对应的底仓体系持仓，自动删除陈旧便签。");
        ClearCycleState();
        return;
    }

    double actualAnchor = FindActualBaseAnchor();
    if(actualAnchor > 0 && MathAbs(actualAnchor - GlobalStartPrice) >= 2.0)
    {
        GlobalStartPrice = actualAnchor;
        highestSlicedLevelUp = (int)MathFloor((GlobalStartPrice - (double)InpOffsetPoints * _Point) /
                                               ((double)InpBaseGridPoints * _Point));
        SaveStartPrice();
        SaveUpperSliceLevel();
        Print("真实底仓与旧便签不一致，已自动以实际底仓价格重建起始价状态：", GlobalStartPrice);
    }
}

//+------------------------------------------------------------------+
//| EA 卸载清理函数                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, "RPL_");
    ObjectsDeleteAll(0, "RiskPanelLine_"); 
    Print("EA已卸载或参数变更，正在清理屏幕残影UI...");
}

//+------------------------------------------------------------------+
//| 获取底仓系统的基准下限 (物理网格线对齐)                          |
//+------------------------------------------------------------------+
double GetBaseAnchor()
{
    if(GlobalStartPrice <= 0) return 0;
    double off = (double)InpOffsetPoints * _Point;
    double step = (double)InpBaseGridPoints * _Point;
    return MathFloor((GlobalStartPrice - off) / step) * step + off;
}

//+------------------------------------------------------------------+
//| 获取密网系统的智能上限                                           |
//+------------------------------------------------------------------+
double GetDenseGridTop()
{
    if(InpDownUpperLimit > 0) return InpDownUpperLimit; 
    if(GlobalStartPrice > 0)  return GetBaseAnchor(); 
    return InpBaseUpperLimit;                 
}

//+------------------------------------------------------------------+
//| 官方底层引擎缓存系统 (彻底统一美分与美元单位)                    |
//+------------------------------------------------------------------+
void UpdateEngineCache(double currentAsk)
{
    if(TimeCurrent() - lastCacheUpdateTime < 1800 && cachedMarginPerLot > 0 && cachedProfitPerLot > 0) return;

    double margin = 0, profit = 0;
    
    if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 1.0, currentAsk, margin)) cachedMarginPerLot = margin;
    if(OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, 1.0, currentAsk, currentAsk - 1.0, profit)) cachedProfitPerLot = MathAbs(profit); 

    if(cachedMarginPerLot > 0 && cachedProfitPerLot > 0)
    {
        cachedBasePrice = currentAsk;
        lastCacheUpdateTime = TimeCurrent();
        PrintFormat("🔄 底层引擎已同步：1手保证金 %.2f，1手跌1美元等值盈亏额 %.2f", cachedMarginPerLot, cachedProfitPerLot);
    }
}

//+------------------------------------------------------------------+
//| 极速换算：估算保证金与点差盈亏                                   |
//+------------------------------------------------------------------+
double EstimateMargin(double volume, double targetPrice)
{
    if(volume <= 0 || cachedMarginPerLot <= 0 || cachedBasePrice <= 0) return 0;
    return volume * (targetPrice / cachedBasePrice) * cachedMarginPerLot;
}

double EstimateProfit(double volume, double openPrice, double closePrice)
{
    if(volume <= 0 || cachedProfitPerLot <= 0) return 0;
    return volume * (closePrice - openPrice) * cachedProfitPerLot; 
}

//+------------------------------------------------------------------+
//| 执行初始底仓建仓                                                 |
//+------------------------------------------------------------------+
bool ExecuteInitialBase(double openPrice)
{
    if(InpPureDenseMode)
    {
        Print("🚀 已开启【纯密网模式】，跳过初始底仓建仓阶段。");
        GlobalStartPrice = -1;
        SaveStartPrice();
        return true; 
    }

    if(openPrice >= InpBaseUpperLimit) return false;
    
    int levels = (int)MathFloor((InpBaseUpperLimit - openPrice) / ((double)InpBaseGridPoints * _Point));
    double vol = NormalizeDouble(levels * InpMinLot, 2);
    
    if(vol > 0)
    {
        double margin = 0;
        if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, vol, openPrice, margin)) margin = 0;
        
        if(margin > 0 && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < margin)
        {
            Alert("致命错误：可用保证金不足！无法建立初始底仓，EA将停止。");
            ExpertRemove();
            return false;
        }
        
        trade.SetExpertMagicNumber(InpBaseMagic);
        if(ConfirmTradeResult(trade.Buy(vol, _Symbol, openPrice, 0, InpBaseUpperLimit, "InitBase"), "建立初始底仓", 0))
        {
            GlobalStartPrice = openPrice;
            SaveStartPrice();
            highestSlicedLevelUp = (int)MathFloor((GlobalStartPrice - (double)InpOffsetPoints * _Point) / ((double)InpBaseGridPoints * _Point));
            SaveUpperSliceLevel();
            Print("🎉 狙击建仓成功！界河正式确立在: ", GlobalStartPrice);
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| 初始化 (含自动洗盘系统)                                          |
//+------------------------------------------------------------------+
int OnInit()
{
    if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
    {
        Alert("严重错误：账户必须为对冲(Hedging)模式，否则无法运行双核网格！");
        return(INIT_FAILED);
    }

    if(!ValidateInputs()) return(INIT_PARAMETERS_INCORRECT);

    InitializeStateNames();
    trade.SetExpertMagicNumber(InpBaseMagic);
    trade.SetMarginMode();
    trade.SetTypeFillingBySymbol(_Symbol);

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    LoadCycleState(bid);
    ReconcileStartState();

    if(exitInProgress || bid >= InpBaseUpperLimit)
    {
        exitInProgress = true;
        GlobalVariableSet(gvExitName, 1.0);
        Print("EA 已进入退出中状态：禁止新交易，等待删单、平仓与清零核验。");
        return(INIT_SUCCEEDED);
    }

    // 保留 v3.97 的重载洗盘行为；参数校验已在此前完成，避免错误参数导致误删挂单。
    int deletedOrders = DeleteAllEAPendingOrders();
    if(deletedOrders > 0) PrintFormat("🧹 初始化已清理 %d 个本 EA 历史挂单，准备重新布阵。", deletedOrders);

    UpdateEngineCache(ask);

    if(GlobalStartPrice == 0)
    {
        if(InpPureDenseMode || InpCustomBasePrice <= 0 || ask <= InpCustomBasePrice)
            ExecuteInitialBase(ask);
    }
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 主循环引擎 (含 5 秒发包节流阀)                                   |
//+------------------------------------------------------------------+
void OnTick()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    if(exitInProgress || bid >= InpBaseUpperLimit)
    {
        ProcessExit();
        return;
    }

    if(GlobalStartPrice == 0 && (InpPureDenseMode || (InpCustomBasePrice > 0 && ask <= InpCustomBasePrice)))
        ExecuteInitialBase(ask);

    UpdateEngineCache(ask); 
    DynamicTPUpdater();
    ManageCrossUpLogic();
    ManageOrderConsolidation();
    DrawRiskPanel();
    
    // 【v3.90 5秒对表发包引擎】
    static datetime lastGridSyncTime = 0;
    datetime currentTime = TimeCurrent();
    if(currentTime / 5 > lastGridSyncTime / 5)
    {
        ManageGridOrders(); 
        lastGridSyncTime = currentTime;
    }
}

//+------------------------------------------------------------------+
//| 切分与断网补偿追偿逻辑                                           |
//+------------------------------------------------------------------+
int SliceOneManagedUnit()
{
    ulong ticket = 0;
    double largestVolume = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong currentTicket = PositionGetTicket(i);
        if(currentTicket == 0 || !PositionSelectByTicket(currentTicket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
           PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY ||
           !IsManagedMagic(PositionGetInteger(POSITION_MAGIC))) continue;

        double volume = PositionGetDouble(POSITION_VOLUME);
        if(volume + VolumeTolerance() < InpMinLot) continue;
        if(volume > largestVolume)
        {
            largestVolume = volume;
            ticket = currentTicket;
        }
    }

    if(ticket == 0) return 0;

    if(largestVolume <= InpMinLot + VolumeTolerance())
    {
        if(ConfirmTradeResult(trade.PositionClose(ticket), "补切整笔最小仓位", ticket)) return 1;
    }
    else
    {
        double volumeToClose = NormalizeDouble(InpMinLot, 2);
        if(ConfirmTradeResult(trade.PositionClosePartial(ticket, volumeToClose), "补切一单位仓位", ticket)) return 1;
    }
    return -1;
}

void SaveSliceProgress(bool upperSystem, int level)
{
    if(upperSystem)
    {
        highestSlicedLevelUp = level;
        SaveUpperSliceLevel();
    }
    else
    {
        lastSlicedLevelDn = level;
        SaveDenseSliceLevel();
    }
}

void ProcessMissedSliceLevels(bool upperSystem, int currentLevel, double step, double offset)
{
    int lastLevel = upperSystem ? highestSlicedLevelUp : lastSlicedLevelDn;
    if(currentLevel <= lastLevel) return;

    int actions = 0;
    for(int level = lastLevel + 1; level <= currentLevel; level++)
    {
        double levelPrice = level * step + offset;
        if(upperSystem && levelPrice <= GlobalStartPrice + _Point)
        {
            SaveSliceProgress(upperSystem, level);
            continue;
        }

        if(CheckHistoryForExit(levelPrice, step))
        {
            SaveSliceProgress(upperSystem, level);
            continue;
        }

        if(actions >= MAX_SLICE_ACTIONS_PER_TICK) break;

        int result = SliceOneManagedUnit();
        if(result > 0)
        {
            actions++;
            SaveSliceProgress(upperSystem, level);
            continue;
        }
        if(result == 0)
        {
            Print("补切层级已越过，但当前没有可减仓位；将该层级记为已处理：", level);
            SaveSliceProgress(upperSystem, currentLevel);
        }
        break;
    }

    if(actions > 0)
        PrintFormat("已补做 %d 个遗漏切分层级，剩余层级将在后续 tick 继续处理。", actions);
}

void ManageCrossUpLogic()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stepUp = (double)InpBaseGridPoints * _Point;
    double stepDn = (double)InpDownGridPoints * _Point;
    double off = (double)InpOffsetPoints * _Point;

    if(GlobalStartPrice > 0 && highestSlicedLevelUp == UNINITIALIZED_LEVEL)
    {
        highestSlicedLevelUp = (int)MathFloor((GlobalStartPrice - off) / stepUp);
        SaveUpperSliceLevel();
    }
    if(lastSlicedLevelDn == UNINITIALIZED_LEVEL)
    {
        lastSlicedLevelDn = (int)MathFloor((bid - off) / stepDn);
        SaveDenseSliceLevel();
    }

    bool inUpperSliceZone = (GlobalStartPrice > 0 && bid >= GlobalStartPrice);
    if(inUpperSliceZone)
    {
        int newLevelUp = (int)MathFloor((bid - off) / stepUp);
        ProcessMissedSliceLevels(true, newLevelUp, stepUp, off);
    }

    // 密网反弹切分也使用相同的持久化补偿机制；避免与上方切分在同一 tick 重复减仓。
    double denseTop = GetDenseGridTop();
    if(!inUpperSliceZone && bid < denseTop)
    {
        int newLevelDn = (int)MathFloor((bid - off) / stepDn);
        ProcessMissedSliceLevels(false, newLevelDn, stepDn, off);
    }
    lastBidLower = bid;
}

//+------------------------------------------------------------------+
//| 订单身份：Magic 为主，Comment 仅兼容 v3.97 遗留仓                |
//+------------------------------------------------------------------+
bool IsStrategicPosition(ulong magic, double volume, double openPrice, string comment)
{
    if(IsMergedMagic(magic)) return true;
    if(volume > InpMinLot + VolumeTolerance()) return true;
    if(magic == InpBaseMagic && GlobalStartPrice > 0 && MathAbs(openPrice - GlobalStartPrice) < 2.0)
        return true;

    // 仅为升级时仍在场的 v3.97 仓位提供辅助兼容，绝不单独作为新仓身份依据。
    if(StringFind(comment, "Base") >= 0) return true;
    return false;
}

int TakeProfitPointsForMagic(ulong magic)
{
    return (magic == InpBaseMagic || magic == InpBaseMergedMagic) ?
           InpBaseTakeProfit : InpDownTakeProfit;
}

//+------------------------------------------------------------------+
//| 动态维护所有订单的止盈参数 (v3.97 体积绝对霸权认证)              |
//+------------------------------------------------------------------+
void DynamicTPUpdater()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID); 
    
    // --- 1. 修正持仓 TP ---
    for(int i=PositionsTotal()-1; i>=0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetString(POSITION_SYMBOL)==_Symbol)
        {
            ulong m = PositionGetInteger(POSITION_MAGIC); 
            double op = PositionGetDouble(POSITION_PRICE_OPEN);
            double tp = PositionGetDouble(POSITION_TP);
            double vol = PositionGetDouble(POSITION_VOLUME);
            double exp = tp;
            
            if(IsManagedMagic(m))
            {
                bool isBase = IsStrategicPosition(m, vol, op, PositionGetString(POSITION_COMMENT));
                exp = isBase ? InpBaseUpperLimit : op + (double)TakeProfitPointsForMagic(m) * _Point;
                    
                // 防御 invalid stops 死循环
                if(!isBase && exp <= bid)
                {
                    Print("🚨 行情已越过网格理论止盈线，触发防倒挂强制收割: ", PositionGetTicket(i));
                    ConfirmTradeResult(trade.PositionClose(PositionGetTicket(i)), "防倒挂强制平仓", PositionGetTicket(i));
                }
                else if(MathAbs(tp - NormalizeDouble(exp, _Digits)) > 0.5*_Point) 
                {
                    ConfirmTradeResult(trade.PositionModify(PositionGetTicket(i), 0, NormalizeDouble(exp, _Digits)),
                                       "更新持仓止盈", PositionGetTicket(i));
                }
            }
        }
    }
    
    // --- 2. 修正挂单 TP ---
    for(int j=OrdersTotal()-1; j>=0; j--)
    {
        if(OrderSelect(OrderGetTicket(j)) && OrderGetString(ORDER_SYMBOL)==_Symbol)
        {
            ulong m = OrderGetInteger(ORDER_MAGIC); 
            double op = OrderGetDouble(ORDER_PRICE_OPEN);
            double tp = OrderGetDouble(ORDER_TP);
            double exp = tp;
            
            if(m==InpBaseMagic || m==InpDownMagic)
            {
                exp = op + (double)TakeProfitPointsForMagic(m) * _Point;
                if(MathAbs(tp - NormalizeDouble(exp, _Digits)) > 0.5*_Point) 
                {
                    ConfirmTradeResult(trade.OrderModify(OrderGetTicket(j), op, 0, NormalizeDouble(exp, _Digits), ORDER_TIME_GTC, 0),
                                       "更新挂单止盈", OrderGetTicket(j));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 风控推演面板 (适配美分账户与 UI 精简)                            |
//+------------------------------------------------------------------+
void DrawRiskPanel()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bal = AccountInfoDouble(ACCOUNT_BALANCE);
    double eq = AccountInfoDouble(ACCOUNT_EQUITY);
    
    double pBot = InpDownLowerLimit;
    double stepUp = (double)InpBaseGridPoints * _Point;
    double stepDn = (double)InpDownGridPoints * _Point;
    double off = (double)InpOffsetPoints * _Point;
    
    int soMode = (int)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);
    double soLevel = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);

    int cntBase=0, cntGrid=0, cntPending=0;
    double curVol=0;
    
    for(int i=0; i<PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetString(POSITION_SYMBOL)==_Symbol)
        {
            ulong m = PositionGetInteger(POSITION_MAGIC);
            if(IsManagedMagic(m))
            {
                double v = PositionGetDouble(POSITION_VOLUME);
                curVol += v;
                if(IsStrategicPosition(m, v, PositionGetDouble(POSITION_PRICE_OPEN), PositionGetString(POSITION_COMMENT))) cntBase++;
                else cntGrid++;
            }
        }
    }
    for(int j=0; j<OrdersTotal(); j++)
    {
        if(OrderSelect(OrderGetTicket(j)) && OrderGetString(ORDER_SYMBOL)==_Symbol)
        {
            ulong m = OrderGetInteger(ORDER_MAGIC);
            if(IsManagedMagic(m)) cntPending++;
        }
    }

    double curMargin = EstimateMargin(curVol, ask);
    double curMarginLevel = (curMargin > 0) ? (eq / curMargin) * 100.0 : 9999.0;

    double vDn = 0, costDn = 0;
    for(int i=0; i<PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetString(POSITION_SYMBOL)==_Symbol)
        {
            ulong m = PositionGetInteger(POSITION_MAGIC);
            if(IsManagedMagic(m))
            {
                double v = PositionGetDouble(POSITION_VOLUME);
                double op = PositionGetDouble(POSITION_PRICE_OPEN);
                vDn += v; costDn += v * op;
            }
        }
    }
    
    double dTop = GetDenseGridTop();
    double sAsk = MathMin(ask, dTop);
    double tDN = MathFloor(sAsk / stepDn) * stepDn + off;
    
    while(tDN >= sAsk || (dTop > 0 && tDN >= dTop)) tDN -= stepDn;
        
    if(tDN >= pBot)
    {
        int n = (int)MathRound((tDN - pBot) / stepDn) + 1;
        double vPending = n * InpMinLot;
        vDn += vPending;
        costDn += vPending * ((tDN + pBot)/2.0); 
    }
    
    double avgOpDn = (vDn > 0) ? costDn / vDn : 0;
    double pnlDn = EstimateProfit(vDn, avgOpDn, pBot); 
    double eqAtDn = bal + pnlDn; 
    double mDn = EstimateMargin(vDn, pBot);
    
    double so_dn_val = 0;
    if(vDn > 0 && cachedProfitPerLot > 0)
    {
        if(soMode == ACCOUNT_STOPOUT_MODE_PERCENT)
        {
            double cMarg = (cachedMarginPerLot / cachedBasePrice) * (soLevel / 100.0);
            double denom = vDn * cachedProfitPerLot - vDn * cMarg;
            so_dn_val = (denom != 0) ? (vDn * cachedProfitPerLot * avgOpDn - bal) / denom : 0;
        }
        else so_dn_val = avgOpDn + (soLevel - bal) / (vDn * cachedProfitPerLot);
    }

    double vF = 0, costF = 0;
    double tUP = MathFloor(InpBaseUpperLimit / stepUp) * stepUp + off;
    if(GlobalStartPrice > 0 || (GlobalStartPrice == 0 && !InpPureDenseMode))
    {
        while(tUP >= GetBaseAnchor() - 0.001)
        {
            if(tUP < InpBaseUpperLimit && tUP >= pBot) { vF += InpMinLot; costF += InpMinLot * tUP; }
            tUP -= stepUp;
        }
    }
    
    double tDN2 = MathFloor(dTop / stepDn) * stepDn + off;
    while(tDN2 >= pBot - 0.001)
    {
        if(tDN2 < dTop - 0.001) { vF += InpMinLot; costF += InpMinLot * tDN2; }
        tDN2 -= stepDn;
    }
    
    double avgOpF = (vF > 0) ? costF / vF : 0;
    double pnlF = EstimateProfit(vF, avgOpF, pBot);
    double mF = EstimateMargin(vF, pBot);
    double eqAtF = bal + pnlF;

    double so_f_val = 0;
    if(vF > 0 && cachedProfitPerLot > 0)
    {
        if(soMode == ACCOUNT_STOPOUT_MODE_PERCENT)
        {
            double cMarg = (cachedMarginPerLot / cachedBasePrice) * (soLevel / 100.0);
            double denom = vF * cachedProfitPerLot - vF * cMarg;
            so_f_val = (denom != 0) ? (vF * cachedProfitPerLot * avgOpF - bal) / denom : 0;
        }
        else so_f_val = avgOpF + (soLevel - bal) / (vF * cachedProfitPerLot);
    }

    double reqF = 0;
    if (InpPsyStopOutLevel > 0 && vF > 0)
    {
        double eqAtPsy = bal + EstimateProfit(vF, avgOpF, InpPsyStopOutLevel);
        double mPsy = EstimateMargin(vF, InpPsyStopOutLevel);
        double thAtPsy = (soMode == ACCOUNT_STOPOUT_MODE_PERCENT) ? mPsy * (soLevel / 100.0) : soLevel;
        if (eqAtPsy < thAtPsy) reqF = thAtPsy - eqAtPsy;
    }

    double maxDens = 0;
    bool isSuperSafe = false;
    
    if(vF > 0 && InpPsyStopOutLevel < avgOpF && cachedProfitPerLot > 0)
    {
        double mPsyPerLot = EstimateMargin(1.0, InpPsyStopOutLevel);
        double thPsyPerLot = (soMode == ACCOUNT_STOPOUT_MODE_PERCENT) ? mPsyPerLot * (soLevel / 100.0) : 0;
        double denom_dens = thPsyPerLot + cachedProfitPerLot * (avgOpF - InpPsyStopOutLevel);
        if(denom_dens > 0)
        {
            double maxV = bal / denom_dens;
            maxDens = (dTop - pBot) / (maxV / InpMinLot) / _Point;
            if(maxDens < 1.0) isSuperSafe = true; 
        }
    }

    // ==========================================
    // 【终极防弹美分换算】：无视各种券商乱七八糟的大小写与后缀
    // ==========================================
    double displayRate = 1.0;
    string accCurrency = AccountInfoString(ACCOUNT_CURRENCY);
    StringToUpper(accCurrency); // 全部转大写强杀
    if(StringFind(accCurrency, "USC") >= 0 || StringFind(accCurrency, "CENT") >= 0) 
    {
        displayRate = 100.0;
    }

    string L[10];
    L[0] = "【风控数据】" + ((GlobalStartPrice == -1) ? " [纯密网模式]" : "");
    L[1] = StringFormat("① 当前EA占用保证金：$%.2f，比例：%.2f%%", curMargin / displayRate, curMarginLevel);
    L[2] = StringFormat("② 价格直达网格底部(%.2f)时，占用：$%.2f，比例：%.2f%%", pBot, mDn / displayRate, (mDn>0?eqAtDn/mDn*100:9999));
    L[3] = StringFormat("③ 网格满载并触底时占用保证金：$%.2f，比例：%.2f%%", mF / displayRate, (mF>0?eqAtF/mF*100:9999));
    
    if(so_dn_val < 0) L[4] = "④ 当前价格直接触底爆仓线：0.00 (资金绝对充裕，黄金归零亦不爆仓)";
    else L[4] = StringFormat("④ 当前价格直接触底爆仓线：%.2f", so_dn_val);
    
    if(so_f_val < 0) L[5] = "⑤ 网格满载时价格触底爆仓线：0.00 (资金绝对充裕，黄金归零亦不爆仓)";
    else L[5] = StringFormat("⑤ 网格满载时价格触底爆仓线：%.2f", so_f_val);
    
    if(reqF <= 0) L[6] = StringFormat("⑥ 极限防爆仓位置 (%.2f) 需补充保证金：$0.00 (安全通过)", InpPsyStopOutLevel);
    else L[6] = StringFormat("⑥ 极限防爆仓位置 (%.2f) 需补充保证金：$%.2f", InpPsyStopOutLevel, reqF / displayRate);
        
    if(isSuperSafe) L[7] = "⑦ 当前仓位可铺设最密网格：(资金过大，当前设置下无爆仓风险)";
    else L[7] = StringFormat("⑦ 当前仓位可铺设最密网格：%.0f 微点", maxDens);
    
    L[8] = StringFormat("⑧ 底仓单量：%d，网格单量：%d，挂单单量：%d，总量：%d", cntBase, cntGrid, cntPending, cntBase+cntGrid+cntPending);
    
    double hSO = MathMax(so_dn_val, so_f_val);
    if(hSO >= pBot) L[9] = "⚠️ 高危：极端行情下，防线之上必然爆仓！";
    else if(MathMin((mDn>0?eqAtDn/mDn*100:9999), (mF>0?eqAtF/mF*100:9999)) < 100) L[9] = "⚠️ 警告：跌至底部时将面临追保 (Margin Call)！";
    else L[9] = "✅ 安全：物理防线内资金完全充裕，系统稳如泰山";

    int spc = InpPanelFontSize + 12; 
    
    for(int i=0; i<10; i++)
    {
        string n = "RPL_" + IntegerToString(i);
        if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_RIGHT_UPPER); 
        ObjectSetInteger(0, n, OBJPROP_XDISTANCE, InpPanelX);
        ObjectSetInteger(0, n, OBJPROP_YDISTANCE, InpPanelY + i*spc); 
        ObjectSetInteger(0, n, OBJPROP_FONTSIZE, InpPanelFontSize);
        ObjectSetString(0, n, OBJPROP_FONT, "微软雅黑"); 
        ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetString(0, n, OBJPROP_TEXT, L[i]);
        
        if(i==0) ObjectSetInteger(0, n, OBJPROP_COLOR, clrGold); 
        else if(i==1) ObjectSetInteger(0, n, OBJPROP_COLOR, clrLightSkyBlue);
        else if(i==6 && reqF > 0) ObjectSetInteger(0, n, OBJPROP_COLOR, clrMagenta); 
        else if(i==9) ObjectSetInteger(0, n, OBJPROP_COLOR, (hSO >= pBot)?clrRed:clrLimeGreen);
        else ObjectSetInteger(0, n, OBJPROP_COLOR, clrWhite);
    }
}

//+------------------------------------------------------------------+
//| 退出状态机：冻结新交易 → 删挂单 → 平持仓 → 核验 → 卸载          |
//+------------------------------------------------------------------+
int DeleteAllEAPendingOrders()
{
    int deleted = 0;
    for(int j = OrdersTotal() - 1; j >= 0; j--)
    {
        ulong ticket = OrderGetTicket(j);
        if(ticket == 0 || !OrderSelect(ticket)) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol || !IsManagedMagic(OrderGetInteger(ORDER_MAGIC))) continue;

        if(ConfirmTradeResult(trade.OrderDelete(ticket), "删除挂单", ticket)) deleted++;
    }
    return deleted;
}

int CloseAllEAPositions()
{
    int closed = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol || !IsManagedMagic(PositionGetInteger(POSITION_MAGIC))) continue;

        if(ConfirmTradeResult(trade.PositionClose(ticket), "平持仓", ticket)) closed++;
    }
    return closed;
}

bool HasManagedExposure()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong positionTicket = PositionGetTicket(i);
        if(positionTicket > 0 && PositionSelectByTicket(positionTicket) &&
           PositionGetString(POSITION_SYMBOL) == _Symbol &&
           IsManagedMagic(PositionGetInteger(POSITION_MAGIC))) return true;
    }
    for(int j = OrdersTotal() - 1; j >= 0; j--)
    {
        ulong orderTicket = OrderGetTicket(j);
        if(orderTicket > 0 && OrderSelect(orderTicket) &&
           OrderGetString(ORDER_SYMBOL) == _Symbol &&
           IsManagedMagic(OrderGetInteger(ORDER_MAGIC))) return true;
    }
    return false;
}

void ProcessExit()
{
    if(!exitInProgress)
    {
        exitInProgress = true;
        GlobalVariableSet(gvExitName, 1.0);
        Print("已触达总目标上限，进入退出中状态并冻结全部新交易。");
    }

    int deleted = DeleteAllEAPendingOrders();
    int closed = CloseAllEAPositions();

    if(!HasManagedExposure())
    {
        ClearCycleState();
        Alert("总目标退出已确认：本 EA 的持仓和挂单均已清零，现自动卸载 EA。");
        ExpertRemove();
        return;
    }

    PrintFormat("退出中：本轮已删除 %d 个挂单、已提交 %d 笔平仓；仍有本 EA 曝险，将在后续 tick 重试。", deleted, closed);
}

//+------------------------------------------------------------------+
//| 查阅历史服务器账单 (扩大至 30 天防遗忘)                          |
//+------------------------------------------------------------------+
bool CheckHistoryForExit(double price, double interval)
{
    if(!HistorySelect(TimeCurrent()-86400*30, TimeCurrent())) return false;
    for(int i=HistoryDealsTotal()-1; i>=0; i--)
    {
        ulong t = HistoryDealGetTicket(i);
        if(HistoryDealGetString(t, DEAL_SYMBOL)==_Symbol &&
           IsManagedMagic(HistoryDealGetInteger(t, DEAL_MAGIC)) &&
           HistoryDealGetInteger(t, DEAL_ENTRY)==DEAL_ENTRY_OUT)
        {
            if(MathAbs(HistoryDealGetDouble(t, DEAL_PRICE) - price) < interval * 0.5) return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| 网格挂单生成器与动态吸尘器 (v3.95 核心升级：死区防抖与滞后缓冲带)|
//+------------------------------------------------------------------+
void ManageGridOrders()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double stepUp = (double)InpBaseGridPoints * _Point;
    double stepDn = (double)InpDownGridPoints * _Point;
    double off = (double)InpOffsetPoints * _Point;
    
    double maxT = 0;
    double baseAnchor = 0;
    
    if(GlobalStartPrice > 0) 
    { 
        maxT = (highestSlicedLevelUp - 1) * stepUp + off; 
        baseAnchor = GetBaseAnchor(); 
    }
    
    double dTop = GetDenseGridTop();
    double curL = MathFloor(ask/stepDn)*stepDn;
    double minValidDn = curL - (InpMaxGridLevels - 1) * stepDn + off;
    
    // 动态吸尘器：清理越界废单（使用两层缓冲带防震荡）
    double deleteBoundDn = minValidDn - 2.0 * stepDn;

    for(int j=OrdersTotal()-1; j>=0; j--)
    {
        if(OrderSelect(OrderGetTicket(j)) && OrderGetString(ORDER_SYMBOL)==_Symbol)
        {
            ulong m = OrderGetInteger(ORDER_MAGIC); 
            double op = OrderGetDouble(ORDER_PRICE_OPEN);
            
            if(m == InpBaseMagic)
            {
                if(GlobalStartPrice <= 0 || op < baseAnchor-0.001 || op > maxT+0.001)
                    ConfirmTradeResult(trade.OrderDelete(OrderGetTicket(j)), "清理越界底仓回补挂单", OrderGetTicket(j));
            }
            else if(m == InpDownMagic)
            {
                if(op < deleteBoundDn-0.001 || op >= dTop-0.001 || op < InpDownLowerLimit)
                    ConfirmTradeResult(trade.OrderDelete(OrderGetTicket(j)), "清理越界密网挂单", OrderGetTicket(j));
            }
        }
    }
    
    // --- 铺设底仓回补单 ---
    if(GlobalStartPrice > 0)
    {
        double curU = MathFloor(ask/stepUp)*stepUp; 
        trade.SetExpertMagicNumber(InpBaseMagic);
        
        for(int i=0; i<100; i++)
        { 
            double t = NormalizeDouble(curU - i*stepUp + off, _Digits);
            if(t < baseAnchor-0.001) break;
            
            // 【死区防抖】：现价必须拉开至少一个 stepUp 间距才允许布雷
            if(t > maxT || ask-t < stepUp) continue;
            
            if(!CheckLevelExists(t, InpBaseMagic, stepUp)) 
                ConfirmTradeResult(trade.BuyLimit(InpMinLot, t, _Symbol, 0, t + (double)InpBaseTakeProfit*_Point, ORDER_TIME_GTC, 0, "GridBuy"), "铺设底仓回补挂单", 0);
        }
    }
    
    // --- 铺设密网游击队单 ---
    trade.SetExpertMagicNumber(InpDownMagic);
    for(int j=0; j<InpMaxGridLevels; j++)
    {
        double t = NormalizeDouble(curL - j*stepDn + off, _Digits);
        
        // 网格铺设下限只检查本候选目标价；不以当前市价作为总停单条件。
        if(t >= dTop-0.001 || t < InpDownLowerLimit || ask-t < stepDn) continue;
            
        if(!CheckLevelExists(t, InpDownMagic, stepDn)) 
            ConfirmTradeResult(trade.BuyLimit(InpMinLot, t, _Symbol, 0, t + (double)InpDownTakeProfit*_Point, ORDER_TIME_GTC, 0, "GridBuy"), "铺设密网挂单", 0);
    }
}

//+------------------------------------------------------------------+
//| 合并散单逻辑与最终排重判定                                       |
//+------------------------------------------------------------------+
bool IsMergeableSourcePosition(ulong sourceMagic)
{
    if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
       PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY ||
       PositionGetInteger(POSITION_MAGIC) != sourceMagic) return false;

    double volume = PositionGetDouble(POSITION_VOLUME);
    if(volume > InpMinLot + VolumeTolerance()) return false;

    // 初始底仓即使最后仅余 0.01，也不能被当成普通碎单合并。
    if(sourceMagic == InpBaseMagic && GlobalStartPrice > 0 &&
       MathAbs(PositionGetDouble(POSITION_PRICE_OPEN) - GlobalStartPrice) < 2.0) return false;

    return true;
}

int CountMergeableSmallPositions(ulong sourceMagic)
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket) && IsMergeableSourcePosition(sourceMagic)) count++;
    }
    return count;
}

int CountManagedItems()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket) &&
           PositionGetString(POSITION_SYMBOL) == _Symbol &&
           IsManagedMagic(PositionGetInteger(POSITION_MAGIC))) count++;
    }
    for(int j = OrdersTotal() - 1; j >= 0; j--)
    {
        ulong ticket = OrderGetTicket(j);
        if(ticket > 0 && OrderSelect(ticket) &&
           OrderGetString(ORDER_SYMBOL) == _Symbol &&
           IsManagedMagic(OrderGetInteger(ORDER_MAGIC))) count++;
    }
    return count;
}

void ManageOrderConsolidation()
{
    bool emergency = (CountManagedItems() >= InpEmergencyLimit);
    if(emergency || CountMergeableSmallPositions(InpBaseMagic) >= InpMergeThreshold)
        ExecuteMerge(InpBaseMagic, InpBaseMergedMagic, "BaseMerged");
    if(emergency || CountMergeableSmallPositions(InpDownMagic) >= InpMergeThreshold)
        ExecuteMerge(InpDownMagic, InpDownMergedMagic, "DownMerged");
}

void ExecuteMerge(ulong sourceMagic, ulong mergedMagic, string comment)
{
    double closedVolume = 0;
    int closedCount = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !PositionSelectByTicket(ticket) || !IsMergeableSourcePosition(sourceMagic)) continue;

        double volume = PositionGetDouble(POSITION_VOLUME);
        if(ConfirmTradeResult(trade.PositionClose(ticket), "关闭待合并碎单", ticket))
        {
            closedVolume += volume;
            closedCount++;
        }
    }

    double normalizedVolume = NormalizeDouble(closedVolume, 2);
    if(normalizedVolume + VolumeTolerance() < InpMinLot) return;

    trade.SetExpertMagicNumber(mergedMagic);
    if(ConfirmTradeResult(trade.Buy(normalizedVolume, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), 0,
                                    InpBaseUpperLimit, comment), "建立合并仓", 0))
        PrintFormat("已将 %d 笔碎单合并为 %.2f 手，新的合并仓 Magic=%I64u。", closedCount, normalizedVolume, mergedMagic);
}

//+------------------------------------------------------------------+
bool CheckLevelExists(double t, ulong m, double i)
{
    for(int p=0; p<PositionsTotal(); p++)
        if(PositionSelectByTicket(PositionGetTicket(p)) && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==m && MathAbs(PositionGetDouble(POSITION_PRICE_OPEN)-t)<i*0.2) return true;
    for(int o=0; o<OrdersTotal(); o++)
        if(OrderSelect(OrderGetTicket(o)) && OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==m && MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-t)<i*0.2) return true;
    return false;
}
//+------------------------------------------------------------------+

