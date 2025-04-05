module BRDPoSChain

go 1.23.0

toolchain go1.24.1

require (
	github.com/VictoriaMetrics/fastcache v1.12.2
	github.com/btcsuite/btcd v0.20.1-beta
	github.com/cespare/cp v1.1.1
	github.com/davecgh/go-spew v1.1.1
	github.com/docker/docker v1.4.2-0.20180625184442-8e610b2b55bf
	github.com/edsrzf/mmap-go v1.0.0
	github.com/fatih/color v1.16.0
	github.com/globalsign/mgo v0.0.0-20181015135952-eeefdecb41b8
	github.com/golang/snappy v1.0.0
	github.com/gorilla/websocket v1.5.3
	github.com/holiman/uint256 v1.3.2
	github.com/huin/goupnp v1.3.0
	github.com/jackpal/go-nat-pmp v1.0.2
	github.com/julienschmidt/httprouter v1.3.0
	github.com/mattn/go-colorable v0.1.13
	github.com/naoina/toml v0.1.2-0.20170918210437-9fafd6967416
	github.com/olekukonko/tablewriter v0.0.5
	github.com/peterh/liner v1.1.1-0.20190123174540-a2c9a5303de7
	github.com/pkg/errors v0.9.1
	github.com/prometheus/prometheus v1.7.2-0.20170814170113-3101606756c5
	github.com/rs/cors v1.7.0
	github.com/steakknife/bloomfilter v0.0.0-20180922174646-6819c0d2a570
	github.com/stretchr/testify v1.10.0
	github.com/syndtr/goleveldb v1.0.1-0.20210819022825-2ae1ddf74ef7
	golang.org/x/crypto v0.36.0
	golang.org/x/sync v0.12.0
	golang.org/x/sys v0.31.0
	golang.org/x/tools v0.31.0
	gopkg.in/check.v1 v1.0.0-20201130134442-10cb98267c6c
	gopkg.in/natefinch/npipe.v2 v2.0.0-20160621034901-c1b8fa8bdcce
	gopkg.in/olebedev/go-duktape.v3 v3.0.0-20210326210528-650f7c854440
)

require (
	github.com/consensys/gnark-crypto v0.17.0
	github.com/crate-crypto/go-kzg-4844 v1.1.0
	github.com/deckarep/golang-set/v2 v2.8.0
	github.com/decred/dcrd/dcrec/secp256k1/v4 v4.4.0
	github.com/dop251/goja v0.0.0-20230605162241-28ee0ee714f3
	github.com/ethereum/c-kzg-4844 v1.0.3
	github.com/fsnotify/fsnotify v1.8.0
	github.com/gballet/go-libpcsclite v0.0.0-20191108122812-4678299bea08
	github.com/go-yaml/yaml v2.1.0+incompatible
	github.com/google/gofuzz v1.2.0
	github.com/google/uuid v1.6.0
	github.com/influxdata/influxdb-client-go/v2 v2.4.0
	github.com/influxdata/influxdb1-client v0.0.0-20220302092344-a9ab5670611c
	github.com/karalabe/hid v1.0.0
	github.com/kylelemons/godebug v1.1.0
	github.com/mattn/go-isatty v0.0.20
	github.com/protolambda/bls12-381-util v0.1.0
	github.com/shirou/gopsutil v3.21.11+incompatible
	github.com/status-im/keycard-go v0.3.3
	github.com/urfave/cli/v2 v2.27.5
	golang.org/x/text v0.23.0
	google.golang.org/protobuf v1.34.2
	gopkg.in/natefinch/lumberjack.v2 v2.2.1
)

require (
	github.com/bits-and-blooms/bitset v1.22.0 // indirect
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/consensys/bavard v0.1.30 // indirect
	github.com/cpuguy83/go-md2man/v2 v2.0.5 // indirect
	github.com/deepmap/oapi-codegen v1.6.0 // indirect
	github.com/dlclark/regexp2 v1.10.0 // indirect
	github.com/go-ole/go-ole v1.3.0 // indirect
	github.com/go-sourcemap/sourcemap v2.1.3+incompatible // indirect
	github.com/google/pprof v0.0.0-20230207041349-798e818bf904 // indirect
	github.com/influxdata/line-protocol v0.0.0-20200327222509-2487e7298839 // indirect
	github.com/kilic/bls12-381 v0.1.0 // indirect
	github.com/kr/pretty v0.3.1 // indirect
	github.com/kr/text v0.2.0 // indirect
	github.com/mattn/go-runewidth v0.0.13 // indirect
	github.com/mmcloughlin/addchain v0.4.0 // indirect
	github.com/naoina/go-stringutil v0.1.0 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	github.com/rivo/uniseg v0.2.0 // indirect
	github.com/rogpeppe/go-internal v1.12.0 // indirect
	github.com/russross/blackfriday/v2 v2.1.0 // indirect
	github.com/steakknife/hamming v0.0.0-20180906055917-c99c65617cd3 // indirect
	github.com/supranational/blst v0.3.14 // indirect
	github.com/tklauser/go-sysconf v0.3.15 // indirect
	github.com/tklauser/numcpus v0.10.0 // indirect
	github.com/xrash/smetrics v0.0.0-20240521201337-686a1a2994c1 // indirect
	github.com/yusufpapurcu/wmi v1.2.4 // indirect
	golang.org/x/mod v0.24.0 // indirect
	golang.org/x/net v0.37.0 // indirect
	golang.org/x/term v0.30.0 // indirect
	gopkg.in/yaml.v2 v2.4.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
	gotest.tools v2.2.0+incompatible // indirect
	rsc.io/tmplfunc v0.0.3 // indirect
)

replace github.com/XinFinOrg/BRDPoSChain => ./

replace github.com/karalabe/hid => github.com/karalabe/hid v1.0.0
