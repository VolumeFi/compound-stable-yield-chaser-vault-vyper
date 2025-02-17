#pragma version 0.4.0
#pragma optimize gas
#pragma evm-version cancun
"""
@title Compound Stable Yield Chaser Vault
@license Apache 2.0
@author Volume.finance
"""

struct SwapInfo:
    route: address[11]
    swap_params: uint256[5][5]
    amount: uint256
    expected: uint256
    pools: address[5]

interface ERC20:
    def balanceOf(_owner: address) -> uint256: view
    def totalSupply() -> uint256: view
    def decimals() -> uint8: view
    def burn(_amount: uint256): nonpayable
    def approve(_spender: address, _value: uint256) -> bool: nonpayable
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable

interface WrappedEth:
    def deposit(): payable
    def withdraw(amount: uint256): nonpayable

interface CurveSwapRouter:
    def exchange(
        _route: address[11],
        _swap_params: uint256[5][5],
        _amount: uint256,
        _expected: uint256,
        _pools: address[5]=empty(address[5]),
        _receiver: address=msg.sender
    ) -> uint256: payable

interface CToken:
    def supply(asset: address, amount: uint256): nonpayable
    def withdraw(asset: address, amount: uint256): nonpayable
    def baseToken() -> address: view
    def balanceOf(_owner: address) -> uint256: view
    def totalSupply() -> uint256: view

VETH: constant(address) = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
DENOMINATOR: constant(uint256) = 10 ** 18
BOBBY_RATE: constant(uint256) = 8 * 10 ** 17
REDEMPTION_FEE_COLLECTOR: public(immutable(address))
REDEMPTION_FEE: public(immutable(uint256))
WETH: public(immutable(address))
Router: public(immutable(address))


event Deposited:
    depositor: address
    token0: address
    asset: address
    amount0: uint256
    balance: uint256

event Released:
    recipient: address
    amount: uint256

event UpdateAsset:
    old_asset: address
    new_asset: address
    amount0: uint256
    amount1: uint256

event Withdrawn:
    user: address
    token0: address
    asset: address
    amount0: uint256
    amount1: uint256
    balance: uint256

event UpdateCompass:
    old_compass: address
    new_compass: address

event UpdateRefundWallet:
    old_refund_wallet: address
    new_refund_wallet: address

event SetPaloma:
    paloma: bytes32

event UpdateEntranceFee:
    old_entrance_fee: uint256
    new_entrance_fee: uint256

event UpdateServiceFeeCollector:
    old_service_fee_collector: address
    new_service_fee_collector: address

event UpdateServiceFee:
    old_service_fee: uint256
    new_service_fee: uint256

event SetBobby:
    old_bobby: address
    new_bobby: address

compass: public(address)
asset: public(address)
c_asset: public(address)
input_token: public(HashMap[address, address])
bobby: public(address)
deposits: public(HashMap[address, uint256])
total_deposit: public(uint256)
refund_wallet: public(address)
entrance_fee: public(uint256)
service_fee_collector: public(address)
service_fee: public(uint256)
paloma: public(bytes32)
nonce_check: public(HashMap[uint256, bool])

@deploy
def __init__(_compass: address, _weth: address, initial_c_asset: address, _router: address, _refund_wallet: address, _entrance_fee: uint256, _service_fee_collector: address, _service_fee: uint256, _redemption_fee: uint256, _redemption_fee_collector: address):
    self.compass = _compass
    self.refund_wallet = _refund_wallet
    self.entrance_fee = _entrance_fee
    self.service_fee_collector = _service_fee_collector
    assert _service_fee < DENOMINATOR, "Invalid service fee"
    self.service_fee = _service_fee
    Router = _router
    WETH = _weth
    REDEMPTION_FEE_COLLECTOR = _redemption_fee_collector
    REDEMPTION_FEE = _redemption_fee
    self.c_asset = initial_c_asset
    _asset: address = staticcall CToken(initial_c_asset).baseToken()
    self.asset = _asset
    log UpdateAsset(empty(address), _asset, 0, 0)
    log UpdateCompass(empty(address), _compass)
    log UpdateRefundWallet(empty(address), _refund_wallet)
    log UpdateEntranceFee(0, _entrance_fee)
    log UpdateServiceFeeCollector(empty(address), _service_fee_collector)
    log UpdateServiceFee(0, _service_fee)

@internal
def _safe_approve(_token: address, _to: address, _value: uint256):
    assert extcall ERC20(_token).approve(_to, _value, default_return_value=True), "Failed approve"

@internal
def _safe_transfer(_token: address, _to: address, _value: uint256):
    assert extcall ERC20(_token).transfer(_to, _value, default_return_value=True), "Failed transfer"

@internal
def _safe_transfer_from(_token: address, _from: address, _to: address, _value: uint256):
    assert extcall ERC20(_token).transferFrom(_from, _to, _value, default_return_value=True), "Failed transferFrom"

@external
@payable
@nonreentrant
def deposit(swap_info: SwapInfo):
    _value: uint256 = msg.value
    _entrance_fee: uint256 = self.entrance_fee
    if _entrance_fee > 0:
        _value -= _entrance_fee
        send(self.refund_wallet, _entrance_fee)
    _asset: address = self.asset
    _amount: uint256 = 0
    if swap_info.route[0] == _asset:
        _amount = staticcall ERC20(_asset).balanceOf(self)
        self._safe_transfer_from(_asset, msg.sender, self, swap_info.amount)
        _amount = staticcall ERC20(_asset).balanceOf(self) - _amount
    elif swap_info.route[0] == VETH and _asset == WETH:
        if _value > swap_info.amount:
            send(msg.sender, unsafe_sub(_value, swap_info.amount))
        else:
            assert _value == swap_info.amount, "Invalid amount"
        extcall WrappedEth(WETH).deposit(value=swap_info.amount)
        _amount = swap_info.amount
    else:
        if swap_info.route[0] == VETH:
            if _value > swap_info.amount:
                send(msg.sender, unsafe_sub(_value, swap_info.amount))
            else:
                assert _value == swap_info.amount, "Invalid amount"
            _amount = staticcall ERC20(_asset).balanceOf(self)
            extcall CurveSwapRouter(Router).exchange(swap_info.route, swap_info.swap_params, swap_info.amount, swap_info.expected, swap_info.pools, value=swap_info.amount)
            _amount = staticcall ERC20(_asset).balanceOf(self) - _amount
        else:
            input_amount: uint256 = staticcall ERC20(swap_info.route[0]).balanceOf(self)
            self._safe_transfer_from(swap_info.route[0], msg.sender, self, swap_info.amount)
            input_amount = staticcall ERC20(swap_info.route[0]).balanceOf(self) - input_amount
            self._safe_approve(swap_info.route[0], Router, input_amount)
            _amount = staticcall ERC20(_asset).balanceOf(self)
            extcall CurveSwapRouter(Router).exchange(swap_info.route, swap_info.swap_params, input_amount, swap_info.expected, swap_info.pools)
            _amount = staticcall ERC20(_asset).balanceOf(self) - _amount
    _c_asset: address = self.c_asset
    self._safe_approve(_asset, _c_asset, _amount)
    extcall CToken(_c_asset).supply(_asset, _amount)
    self.input_token[msg.sender] = swap_info.route[0]
    _amount = _amount * 10 ** convert(staticcall ERC20(self.bobby).decimals(), uint256) // 10 ** convert(staticcall ERC20(_asset).decimals(), uint256)
    self.deposits[msg.sender] += _amount
    self.total_deposit += _amount
    log Deposited(msg.sender, swap_info.route[0], _asset, swap_info.amount, _amount)

@internal
def _paloma_check():
    assert msg.sender == self.compass, "Not compass"
    assert self.paloma == convert(slice(msg.data, unsafe_sub(len(msg.data), 32), 32), bytes32), "Invalid paloma"

@external
def change_asset(_new_c_asset: address, swap_info: SwapInfo):
    self._paloma_check()
    old_asset: address = self.asset
    _new_asset: address = staticcall CToken(_new_c_asset).baseToken()
    assert old_asset != _new_asset, "Already updated asset"
    amount: uint256 = staticcall ERC20(old_asset).balanceOf(self)
    _c_asset: address = self.c_asset
    old_c_asset_balance: uint256 = staticcall ERC20(self.c_asset).balanceOf(self)
    _amount: uint256 = 0
    if old_c_asset_balance > 0:
        extcall CToken(_c_asset).withdraw(old_asset, max_value(uint256))
        amount = staticcall ERC20(old_asset).balanceOf(self) - amount
        self._safe_approve(old_asset, Router, amount)
        _amount = staticcall ERC20(_new_asset).balanceOf(self)
        extcall CurveSwapRouter(Router).exchange(swap_info.route, swap_info.swap_params, amount, swap_info.expected, swap_info.pools)
        _amount = staticcall ERC20(_new_asset).balanceOf(self) - _amount
        assert _amount > 0, "Invalid swap"
        _service_fee: uint256 = _amount * self.service_fee // DENOMINATOR
        if _service_fee > 0:
            self._safe_transfer(_new_asset, self.service_fee_collector, _service_fee)
            _amount -= _service_fee
        self._safe_approve(_new_asset, _new_c_asset, _amount)
        extcall CToken(_new_c_asset).supply(_new_asset, max_value(uint256))
    self.asset = _new_asset
    self.c_asset = _new_c_asset
    log UpdateAsset(old_asset, _new_asset, amount, _amount)

@external
def set_bobby(_bobby: address):
    self._paloma_check()
    assert _bobby != empty(address), "Invalid bobby"
    assert self.bobby == empty(address), "Already set bobby"
    self.bobby = _bobby
    log SetBobby(empty(address), _bobby)

@external
def release_bobby(recipient: address, amount: uint256, nonce: uint256):
    self._paloma_check()
    assert not self.nonce_check[nonce], "Already released"
    self.nonce_check[nonce] = True
    self.deposits[recipient] -= amount
    self.total_deposit -= amount
    log Released(recipient, amount)

@external
@view
def asset_balance(owner: address) -> uint256:
    _bobby: address = self.bobby
    return staticcall ERC20(self.c_asset).balanceOf(self) * staticcall ERC20(_bobby).balanceOf(owner) // staticcall ERC20(_bobby).totalSupply()

@external
@nonreentrant
def withdraw(swap_info: SwapInfo, _amount: uint256, output_token: address = empty(address)):
    _asset: address = self.asset
    _c_asset: address = self.c_asset
    _bobby: address = self.bobby
    assert _amount > 0, "Invalid withdraw"
    _total_supply: uint256 = staticcall ERC20(_bobby).totalSupply()
    self._safe_transfer_from(_bobby, msg.sender, self, _amount)
    extcall ERC20(_bobby).burn(_amount)
    extcall CToken(_c_asset).withdraw(_asset, max_value(uint256))
    asset_balance: uint256 = staticcall ERC20(_asset).balanceOf(self)
    _total_bobby: uint256 = staticcall ERC20(_bobby).totalSupply() + self.total_deposit
    _asset_for_bobby: uint256 = _total_bobby * 10 ** convert(staticcall ERC20(_asset).decimals(), uint256) // 10 ** convert(staticcall ERC20(_bobby).decimals(), uint256)
    benefit: uint256 = 0
    if _asset_for_bobby > asset_balance:
        benefit = asset_balance - _asset_for_bobby
    withdraw_balance: uint256 = _amount * BOBBY_RATE * 10 ** convert(staticcall ERC20(_asset).decimals(), uint256) // 10 ** convert(staticcall ERC20(_bobby).decimals(), uint256)
    if benefit > 0:
        withdraw_balance += benefit * _amount // _total_supply
    if withdraw_balance > asset_balance:
        withdraw_balance = asset_balance
    _redemption_fee: uint256 = withdraw_balance * REDEMPTION_FEE // DENOMINATOR
    if _redemption_fee > 0:
        self._safe_transfer(_asset, REDEMPTION_FEE_COLLECTOR, _redemption_fee)
        withdraw_balance -= _redemption_fee
    _output_token: address = output_token
    out_amount: uint256 = 0
    if _output_token == empty(address):
        _output_token = self.input_token[msg.sender]
    if _output_token == _asset:
        self._safe_transfer(_asset, msg.sender, withdraw_balance)
    elif _output_token == VETH and _asset == WETH: # this is for xDAI chain
        extcall WrappedEth(WETH).withdraw(withdraw_balance)
        send(msg.sender, withdraw_balance)
    else:
        self._safe_approve(_asset, Router, withdraw_balance)
        if _output_token == VETH:
            out_amount = self.balance
            extcall CurveSwapRouter(Router).exchange(swap_info.route, swap_info.swap_params, withdraw_balance, swap_info.expected, swap_info.pools)
            out_amount = self.balance - out_amount
            send(msg.sender, out_amount)
        else:
            out_amount = staticcall ERC20(_output_token).balanceOf(self)
            extcall CurveSwapRouter(Router).exchange(swap_info.route, swap_info.swap_params, withdraw_balance, swap_info.expected, swap_info.pools)
            out_amount = staticcall ERC20(_output_token).balanceOf(self) - out_amount
            self._safe_transfer(_output_token, msg.sender, out_amount)
        assert out_amount > 0, "Invalid swap"
    log Withdrawn(msg.sender, _output_token, _asset, out_amount, withdraw_balance, _amount)

@external
@view
def withdraw_amount(_amount: uint256) -> uint256:
    _asset: address = self.asset
    _c_asset: address = self.c_asset
    _bobby: address = self.bobby
    _total_supply: uint256 = staticcall ERC20(_bobby).totalSupply()
    asset_balance: uint256 = staticcall ERC20(_c_asset).balanceOf(self)
    _total_bobby: uint256 = staticcall ERC20(_bobby).totalSupply() + self.total_deposit
    _asset_for_bobby: uint256 = _total_bobby * 10 ** convert(staticcall ERC20(_asset).decimals(), uint256) // 10 ** convert(staticcall ERC20(_bobby).decimals(), uint256)
    benefit: uint256 = 0
    if _asset_for_bobby > asset_balance:
        benefit = asset_balance - _asset_for_bobby
    withdraw_balance: uint256 = _amount * BOBBY_RATE * 10 ** convert(staticcall ERC20(_asset).decimals(), uint256) // 10 ** convert(staticcall ERC20(_bobby).decimals(), uint256)
    if benefit > 0:
        withdraw_balance += benefit * _amount // _total_supply
    if withdraw_balance > asset_balance:
        withdraw_balance = asset_balance
    _redemption_fee: uint256 = withdraw_balance * REDEMPTION_FEE // DENOMINATOR
    if _redemption_fee > 0:
        withdraw_balance -= _redemption_fee
    return withdraw_balance

@external
def update_compass(new_compass: address):
    self._paloma_check()
    self.compass = new_compass
    log UpdateCompass(msg.sender, new_compass)

@external
def set_paloma():
    assert msg.sender == self.compass and self.paloma == empty(bytes32) and len(msg.data) == 36, "Invalid"
    _paloma: bytes32 = convert(slice(msg.data, 4, 32), bytes32)
    self.paloma = _paloma
    log SetPaloma(_paloma)

@external
def update_refund_wallet(new_refund_wallet: address):
    self._paloma_check()
    old_refund_wallet: address = self.refund_wallet
    self.refund_wallet = new_refund_wallet
    log UpdateRefundWallet(old_refund_wallet, new_refund_wallet)

@external
def update_entrance_fee(new_entrance_fee: uint256):
    self._paloma_check()
    old_entrance_fee: uint256 = self.entrance_fee
    self.entrance_fee = new_entrance_fee
    log UpdateEntranceFee(old_entrance_fee, new_entrance_fee)

@external
def update_service_fee_collector(new_service_fee_collector: address):
    self._paloma_check()
    old_service_fee_collector: address = self.service_fee_collector
    self.service_fee_collector = new_service_fee_collector
    log UpdateServiceFeeCollector(old_service_fee_collector, new_service_fee_collector)

@external
def update_service_fee(new_service_fee: uint256):
    self._paloma_check()
    assert new_service_fee < DENOMINATOR, "Invalid service fee"
    old_service_fee: uint256 = self.service_fee
    self.service_fee = new_service_fee
    log UpdateServiceFee(old_service_fee, new_service_fee)

@external
@payable
def __default__():
    pass