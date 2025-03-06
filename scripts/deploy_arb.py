from ape import accounts, project, networks


def main():
    acct = accounts.load("deployer_account")
    compass = "0x3c1864a873879139C1BD87c7D95c4e475A91d19C"
    weth = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
    router = "0x2191718CD32d02B8E60BAdFFeA33E4B5DD9A0A0D"
    refund_wallet = "0x6dc0A87638CD75Cc700cCdB226c7ab6C054bc70b"
    entrance_fee = 3_000_000_000_000_000  # 10$
    service_fee_collector = "0xe693603C9441f0e645Af6A5898b76a60dbf757F4"
    service_fee = 500_000_000_000_000  # 0.05%
    redemption_fee = 10_000_000_000_000_000  # 1%
    redemption_fee_collector = "0x05B51C484146170240497CE3Ce18aCc6AF2ABC28"
    initial_c_asset = "0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf"
    initial_nonce = 6
    base_fee = networks.active_provider.base_fee
    priority_fee = networks.active_provider.priority_fee
    max_base_fee = int(base_fee * 1.5 + priority_fee)
    kw = {
        'max_fee': max_base_fee,
        'max_priority_fee': priority_fee}
    vault = project.vault.deploy(compass, weth, initial_c_asset, router, refund_wallet, entrance_fee, service_fee_collector, service_fee, redemption_fee, redemption_fee_collector, initial_nonce, sender=acct, **kw)

    print(vault)
