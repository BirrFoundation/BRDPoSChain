package BRCxlending

import (
	"math/big"
	"reflect"
	"testing"

	"BRDPoSChain/BRCx"
	"BRDPoSChain/BRCx/tradingstate"
	"BRDPoSChain/BRCxlending/lendingstate"
	"BRDPoSChain/common"
	"BRDPoSChain/core/rawdb"
	"BRDPoSChain/core/types"
)

func Test_getCancelFeeV1(t *testing.T) {
	type CancelFeeArg struct {
		collateralTokenDecimal *big.Int
		collateralPrice        *big.Int
		borrowFeeRate          *big.Int
		order                  *lendingstate.LendingItem
	}
	tests := []struct {
		name string
		args CancelFeeArg
		want *big.Int
	}{
		// zero fee test: LEND
		{
			"zero fee getCancelFeeV1: LEND",
			CancelFeeArg{
				collateralTokenDecimal: common.Big1,
				collateralPrice:        common.Big1,
				borrowFeeRate:          common.Big0,
				order: &lendingstate.LendingItem{
					Quantity: new(big.Int).SetUint64(10000),
					Side:     tradingstate.Ask,
				},
			},
			common.Big0,
		},

		// zero fee test: BORROW
		{
			"zero fee getCancelFeeV1: BORROW",
			CancelFeeArg{
				collateralTokenDecimal: common.Big1,
				collateralPrice:        common.Big1,
				borrowFeeRate:          common.Big0,
				order: &lendingstate.LendingItem{
					Quantity: new(big.Int).SetUint64(10000),
					Side:     tradingstate.Bid,
				},
			},
			common.Big0,
		},

		// test getCancelFee: LEND
		{
			"test getCancelFeeV1:: LEND",
			CancelFeeArg{
				collateralTokenDecimal: common.Big1,
				collateralPrice:        common.Big1,
				borrowFeeRate:          new(big.Int).SetUint64(30), // 30/10000= 0.3%
				order: &lendingstate.LendingItem{
					Quantity: new(big.Int).SetUint64(10000),
					Side:     tradingstate.Ask,
				},
			},
			common.Big3,
		},

		// test getCancelFee:: BORROW
		{
			"test getCancelFeeV1:: BORROW",
			CancelFeeArg{
				collateralTokenDecimal: common.Big1,
				collateralPrice:        common.Big1,
				borrowFeeRate:          new(big.Int).SetUint64(30), // 30/10000= 0.3%
				order: &lendingstate.LendingItem{
					Quantity: new(big.Int).SetUint64(10000),
					Side:     tradingstate.Bid,
				},
			},
			common.Big3,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := getCancelFeeV1(tt.args.collateralTokenDecimal, tt.args.collateralPrice, tt.args.borrowFeeRate, tt.args.order); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("getCancelFeeV1() = %v, want %v", got, tt.want)
			}
		})
	}
}

func Test_getCancelFee(t *testing.T) {
	BRCx := BRCx.New(&BRCx.DefaultConfig)
	db := rawdb.NewMemoryDatabase()
	stateCache := tradingstate.NewDatabase(db)
	tradingStateDb, _ := tradingstate.New(types.EmptyRootHash, stateCache)

	testTokenA := common.HexToAddress("0x1200000000000000000000000000000000000002")
	testTokenB := common.HexToAddress("0x1300000000000000000000000000000000000003")
	// set decimal
	// tokenA has decimal 10^18
	BRCx.SetTokenDecimal(testTokenA, common.BasePrice)
	// tokenB has decimal 10^8
	BRCx.SetTokenDecimal(testTokenB, new(big.Int).Exp(big.NewInt(10), big.NewInt(8), nil))

	// set tokenAPrice = 1 BRC
	tradingStateDb.SetMediumPriceBeforeEpoch(tradingstate.GetTradingOrderBookHash(testTokenA, common.BRCNativeAddressBinary), common.BasePrice)
	// set tokenBPrice = 1 BRC
	tradingStateDb.SetMediumPriceBeforeEpoch(tradingstate.GetTradingOrderBookHash(testTokenB, common.BRCNativeAddressBinary), common.BasePrice)

	l := New(BRCx)

	type CancelFeeArg struct {
		borrowFeeRate *big.Int
		order         *lendingstate.LendingItem
	}
	tests := []struct {
		name string
		args CancelFeeArg
		want *big.Int
	}{
		// LENDING TOKEN: testTokenA
		// COLLATERAL TOKEN: BRC

		// zero fee test: LEND
		{
			"TokenA/BRCzero fee test: LEND",
			CancelFeeArg{
				borrowFeeRate: common.Big0,
				order: &lendingstate.LendingItem{
					LendingToken:    testTokenA,
					CollateralToken: common.BRCNativeAddressBinary,
					Quantity:        new(big.Int).SetUint64(10000),
					Side:            lendingstate.Investing,
				},
			},
			common.Big0,
		},

		// zero fee test: BORROW
		{
			"TokenA/BRC zero fee test: BORROW",
			CancelFeeArg{
				borrowFeeRate: common.Big0,
				order: &lendingstate.LendingItem{
					LendingToken:    testTokenA,
					CollateralToken: common.BRCNativeAddressBinary,
					Quantity:        new(big.Int).SetUint64(10000),
					Side:            lendingstate.Borrowing,
				},
			},
			common.Big0,
		},

		// test getCancelFee: LEND
		{
			"TokenA/BRC test getCancelFee:: LEND",
			CancelFeeArg{
				borrowFeeRate: new(big.Int).SetUint64(30), // 30/10000= 0.3%
				order: &lendingstate.LendingItem{
					LendingToken:    testTokenA,
					CollateralToken: common.BRCNativeAddressBinary,
					Quantity:        new(big.Int).SetUint64(10000),
					Side:            lendingstate.Investing,
				},
			},
			common.RelayerLendingCancelFee,
		},

		// test getCancelFee:: BORROW
		{
			"TokenA/BRC test getCancelFee:: BORROW",
			CancelFeeArg{
				borrowFeeRate: new(big.Int).SetUint64(30), // 30/10000= 0.3%
				order: &lendingstate.LendingItem{
					LendingToken:    testTokenA,
					CollateralToken: common.BRCNativeAddressBinary,
					Quantity:        new(big.Int).SetUint64(10000),
					Side:            lendingstate.Borrowing,
				},
			},
			common.RelayerLendingCancelFee,
		},

		// LENDING TOKEN: BRC
		// COLLATERAL TOKEN: testTokenA

		// zero fee test: LEND
		{
			"BRC/TokenA zero fee test: LEND",
			CancelFeeArg{
				borrowFeeRate: common.Big0,
				order: &lendingstate.LendingItem{
					LendingToken:    common.BRCNativeAddressBinary,
					CollateralToken: testTokenA,
					Quantity:        new(big.Int).SetUint64(10000),
					Side:            lendingstate.Investing,
				},
			},
			common.Big0,
		},

		// zero fee test: BORROW
		{
			"BRC/TokenA zero fee test: BORROW",
			CancelFeeArg{
				borrowFeeRate: common.Big0,
				order: &lendingstate.LendingItem{
					LendingToken:    common.BRCNativeAddressBinary,
					CollateralToken: testTokenA,
					Quantity:        new(big.Int).SetUint64(10000),
					Side:            lendingstate.Borrowing,
				},
			},
			common.Big0,
		},

		// test getCancelFee: LEND
		{
			"BRC/TokenA  test getCancelFee:: LEND",
			CancelFeeArg{
				borrowFeeRate: new(big.Int).SetUint64(30), // 30/10000= 0.3%
				order: &lendingstate.LendingItem{
					LendingToken:    common.BRCNativeAddressBinary,
					CollateralToken: testTokenA,
					Quantity:        new(big.Int).SetUint64(10000),
					Side:            lendingstate.Investing,
				},
			},
			common.RelayerLendingCancelFee,
		},

		// test getCancelFee:: BORROW
		{
			"BRC/TokenA  test getCancelFee:: BORROW",
			CancelFeeArg{
				borrowFeeRate: new(big.Int).SetUint64(30), // 30/10000= 0.3%
				order: &lendingstate.LendingItem{
					LendingToken:    common.BRCNativeAddressBinary,
					CollateralToken: testTokenA,
					Quantity:        new(big.Int).SetUint64(10000),
					Side:            lendingstate.Borrowing,
				},
			},
			common.RelayerLendingCancelFee,
		},

		// LENDING TOKEN: testTokenB
		// COLLATERAL TOKEN: testTokenA

		// zero fee test: LEND
		{
			"TokenB/TokenA zero fee test: LEND",
			CancelFeeArg{
				borrowFeeRate: common.Big0,
				order: &lendingstate.LendingItem{
					LendingToken:    testTokenB,
					CollateralToken: testTokenA,
					Quantity:        new(big.Int).SetUint64(10000),
					Side:            lendingstate.Investing,
				},
			},
			common.Big0,
		},

		// zero fee test: BORROW
		{
			"TokenB/TokenA zero fee test: BORROW",
			CancelFeeArg{
				borrowFeeRate: common.Big0,
				order: &lendingstate.LendingItem{
					LendingToken:    testTokenB,
					CollateralToken: testTokenA,
					Quantity:        new(big.Int).SetUint64(10000),
					Side:            lendingstate.Borrowing,
				},
			},
			common.Big0,
		},

		// test getCancelFee: LEND
		{
			"TokenB/TokenA  test getCancelFee:: LEND",
			CancelFeeArg{
				borrowFeeRate: new(big.Int).SetUint64(30), // 30/10000= 0.3%
				order: &lendingstate.LendingItem{
					LendingToken:    testTokenB,
					CollateralToken: testTokenA,
					Quantity:        new(big.Int).SetUint64(10000),
					Side:            lendingstate.Investing,
				},
			},
			new(big.Int).Exp(big.NewInt(10), big.NewInt(5), nil),
		},

		// test getCancelFee:: BORROW
		{
			"TokenB/TokenA  test getCancelFee:: BORROW",
			CancelFeeArg{
				borrowFeeRate: new(big.Int).SetUint64(30), // 30/10000= 0.3%
				order: &lendingstate.LendingItem{
					LendingToken:    testTokenB,
					CollateralToken: testTokenA,
					Quantity:        new(big.Int).SetUint64(10000),
					Side:            lendingstate.Borrowing,
				},
			},
			common.RelayerLendingCancelFee,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got, _ := l.getCancelFee(nil, nil, tradingStateDb, tt.args.order, tt.args.borrowFeeRate); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("getCancelFee() = %v, want %v", got, tt.want)
			}
		})
	}

	// testcase: can't get price of token in BRC
	testTokenC := common.HexToAddress("0x1400000000000000000000000000000000000004")
	BRCx.SetTokenDecimal(testTokenC, big.NewInt(1))
	tokenCOrder := CancelFeeArg{
		borrowFeeRate: new(big.Int).SetUint64(100), // 100/10000= 1%
		order: &lendingstate.LendingItem{
			Quantity:        new(big.Int).SetUint64(10000),
			CollateralToken: testTokenC,
			LendingToken:    testTokenA,
			Side:            lendingstate.Borrowing,
		},
	}
	if fee, _ := l.getCancelFee(nil, nil, tradingStateDb, tokenCOrder.order, tokenCOrder.borrowFeeRate); fee != nil && fee.Sign() != 0 {
		t.Errorf("getCancelFee() = %v, want %v", fee, common.Big0)
	}
}

func TestGetLendQuantity(t *testing.T) {
	depositRate := big.NewInt(150)
	lendQuantity := new(big.Int).Mul(big.NewInt(1000), common.BasePrice)
	collateralLocked, _ := new(big.Int).SetString("1000000000000000000000", 10) // 1000
	collateralLocked = new(big.Int).Mul(big.NewInt(150), collateralLocked)
	collateralLocked = new(big.Int).Div(collateralLocked, big.NewInt(100))
	type GetLendQuantityArg struct {
		takerSide              string
		collateralTokenDecimal *big.Int
		depositRate            *big.Int
		collateralPrice        *big.Int
		takerBalance           *big.Int
		makerBalance           *big.Int
		quantityToLend         *big.Int
	}
	tests := []struct {
		name         string
		args         GetLendQuantityArg
		lendQuantity *big.Int
		rejectMaker  bool
	}{
		{
			"taker: BORROW, takerBalance = 0, reject taker, makerBalance = 0",
			GetLendQuantityArg{
				lendingstate.Borrowing,
				common.BasePrice,
				depositRate,
				common.BasePrice,
				common.Big0,
				common.Big0,
				lendQuantity,
			},
			common.Big0,
			false,
		},
		{
			"taker: BORROW, takerBalance = 0, reject taker,  makerBalance > 0",
			GetLendQuantityArg{
				lendingstate.Borrowing,
				common.BasePrice,
				depositRate,
				common.BasePrice,
				common.Big0,
				lendQuantity,
				lendQuantity,
			},
			common.Big0,
			false,
		},
		{
			"taker: BORROW, takerBalance not enough, reject partial of taker",
			GetLendQuantityArg{
				lendingstate.Borrowing,
				common.BasePrice,
				depositRate,
				common.BasePrice,
				new(big.Int).Div(collateralLocked, big.NewInt(2)), // 1/2
				lendQuantity,
				lendQuantity,
			},
			new(big.Int).Div(lendQuantity, big.NewInt(2)),
			false,
		},
		{
			"taker: BORROW, makerBalance = 0, reject maker",
			GetLendQuantityArg{
				lendingstate.Borrowing,
				common.BasePrice,
				depositRate,
				common.BasePrice,
				new(big.Int).Div(collateralLocked, big.NewInt(2)),
				common.Big0,
				lendQuantity,
			},
			common.Big0,
			true,
		},
		{
			"taker: BORROW, makerBalance not enough, reject partial of maker",
			GetLendQuantityArg{
				lendingstate.Borrowing,
				common.BasePrice,
				depositRate,
				common.BasePrice,
				collateralLocked,
				new(big.Int).Div(lendQuantity, big.NewInt(2)),
				lendQuantity,
			},
			new(big.Int).Div(lendQuantity, big.NewInt(2)),
			true,
		},
		{
			"taker: BORROW, don't reject",
			GetLendQuantityArg{
				lendingstate.Borrowing,
				common.BasePrice,
				depositRate,
				common.BasePrice,
				collateralLocked,
				lendQuantity,
				lendQuantity,
			},
			lendQuantity,
			false,
		},

		{
			"taker: INVEST, makerBalance = 0, reject maker",
			GetLendQuantityArg{
				lendingstate.Investing,
				common.BasePrice,
				depositRate,
				common.BasePrice,
				new(big.Int).Div(collateralLocked, big.NewInt(2)),
				common.Big0,
				lendQuantity,
			},
			common.Big0,
			true,
		},
		{
			"taker: INVEST, takerBalance not enough, reject partial of taker",
			GetLendQuantityArg{
				lendingstate.Investing,
				common.BasePrice,
				depositRate,
				common.BasePrice,
				new(big.Int).Div(lendQuantity, big.NewInt(2)), // 1/2
				collateralLocked,
				lendQuantity,
			},
			new(big.Int).Div(lendQuantity, big.NewInt(2)),
			false,
		},
		{
			"taker: INVEST, makerBalance = 0, reject maker",
			GetLendQuantityArg{
				lendingstate.Investing,
				common.BasePrice,
				depositRate,
				common.BasePrice,
				common.Big0,
				new(big.Int).Div(collateralLocked, big.NewInt(2)),
				lendQuantity,
			},
			common.Big0,
			false,
		},
		{
			"taker: INVEST, makerBalance is enough, takerBalance = 0 -> reject taker",
			GetLendQuantityArg{
				lendingstate.Investing,
				common.BasePrice,
				depositRate,
				common.BasePrice,
				common.Big0,
				collateralLocked,
				lendQuantity,
			},
			common.Big0,
			false,
		},
		{
			"taker: INVEST, makerBalance not enough, reject partial of maker",
			GetLendQuantityArg{
				lendingstate.Investing,
				common.BasePrice,
				depositRate,
				common.BasePrice,
				collateralLocked,
				new(big.Int).Div(collateralLocked, big.NewInt(2)),
				lendQuantity,
			},
			new(big.Int).Div(lendQuantity, big.NewInt(2)),
			true,
		},
		{
			"taker: INVEST, don't reject",
			GetLendQuantityArg{
				lendingstate.Investing,
				common.BasePrice,
				depositRate,
				common.BasePrice,
				lendQuantity,
				collateralLocked,
				lendQuantity,
			},
			lendQuantity,
			false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, got1 := GetLendQuantity(tt.args.takerSide, tt.args.collateralTokenDecimal, tt.args.depositRate, tt.args.collateralPrice, tt.args.takerBalance, tt.args.makerBalance, tt.args.quantityToLend)
			if !reflect.DeepEqual(got, tt.lendQuantity) {
				t.Errorf("GetLendQuantity() got = %v, want %v", got, tt.lendQuantity)
			}
			if got1 != tt.rejectMaker {
				t.Errorf("GetLendQuantity() got1 = %v, want %v", got1, tt.rejectMaker)
			}
		})
	}
}
