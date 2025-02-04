-- create table tol.s7_defi_wallets_start 
-- as
-- select distinct on(address) address, tx_lt, jetton_master, "owner", balance from parsed.jetton_wallet_balances 
-- where tx_lt < 51304152000000 order by address, tx_lt desc
with wallets_start as (
  select * from tol.s7_defi_wallets_start
), wallets_end as (
  select address, last_transaction_lt as tx_lt, jetton as jetton_master, "owner", balance from jetton_wallets
), jvault_pools as (
 select address as pool_address from nft_items ni where collection_address =upper('0:184b700ed8d685af9fb0975094f103220b1acfd0e117627f368aa9ee493f452a')
), jvault_pool_tvls as (
 select pool_address, 
  coalesce (sum( (select price_usd from prices.agg_prices ap where ap.base = jetton_master and price_time < 1734433200 order by price_time desc limit 1) * balance / 1e6), 0)
  +
  coalesce (sum( (select tvl_usd / total_supply from prices.dex_pool_history dph where pool = jetton_master and timestamp < 1734433200 order by timestamp desc limit 1) * balance), 0)
   as value_usd
   from wallets_end b
   join jvault_pools p on p.pool_address = b."owner"
   group by 1
), jvault_lp_tokens as (
   select jm.address as lp_master, pool_address from jetton_masters jm join jvault_pools p on p.pool_address =admin_address
), jvault_balances_before as (
 select ed.address, lp_master, balance from wallets_start b
 join tol.enrollment_degen ed on ed.address = b."owner"
 join jvault_lp_tokens on lp_master = b.jetton_master
), jvault_balances_after as (
 select ed.address, lp_master, balance from wallets_end b
 join tol.enrollment_degen ed on ed.address = b."owner"
 join jvault_lp_tokens on lp_master = b.jetton_master
), jvault_balances_delta as (
 select address, lp_master, coalesce(jvault_balances_after.balance, 0) - coalesce(jvault_balances_before.balance, 0) as balance_delta
 from jvault_balances_after left join jvault_balances_before using(address, lp_master) 
), jvault_total_supply as (
   select lp_master, sum(balance) as total_supply
   from wallets_end b
   join jvault_lp_tokens on lp_master = b.jetton_master
   group by 1
   having sum(balance) > 0
), jvault_impact as (
 select address, sum(value_usd * balance_delta / total_supply) as tvl_impact, count(balance_delta), null::bigint as min_utime, null::bigint as max_utime
 from jvault_balances_delta
 join jvault_total_supply using(lp_master)
 join jvault_lp_tokens using(lp_master)
 join jvault_pool_tvls using(pool_address)
 group by 1
), settleton_pools as (
  select upper('0:64216a0ead5819dca7d1719fc912cfa6673665a1c5fcf7338ca5b2ce65f12f80') as pool_address -- WEB3 Vault
  union all
  select upper('0:9be109c3d18d14d6f271f1c311831aef109c2f02062f504726af26ba707f0292') as pool_address -- SettleTON Index - Middle 1
  union all
  select upper('0:f26a93829fdf8448a4ed3cce22a7c92433be18fb668e63cf048a96c5b27fffaa') as pool_address -- JVT Vault
  union all
  select upper('0:ab9d7bda5f91c06fc3cf737acfed24b63080a65db1b5e95400d503a24c047ed5') as pool_address -- DUST Vault
  union all
  select upper('0:3848b9a49c1d1a8e9c7101e5a3a80a5638ba968d52882bf34ef4c8eb4090cc60') as pool_address -- HYDRA Vault
  union all
  select upper('0:56f5e805e4e407d61a20ad94c83e3aaefa0854be28c633f658aca4c679f8c5e7') as pool_address -- USDT Vault
  union all
  select upper('0:dacaea937930943b921d18c34da7ed31d95c5ec17948b2246554b2c6422b2747') as pool_address -- DYOR Vault
  union all
  select upper('0:5b46607213a02eec4061be961e41f69a6bfdb4ccb56b2a7ae5d38d25b42eff1d') as pool_address -- JETTON Vault
  union all
  select upper('0:df2807a89cb6f0f7244847e632a8c4dee6cee7262006a7c3699d696b092040d4') as pool_address -- STORM Vault
), settleton_pool_tvls as (
 select pool_address, 
  coalesce (sum( (select tvl_usd / total_supply from prices.dex_pool_history dph where pool = jetton_master and timestamp < 1734433200 order by timestamp desc limit 1) * balance), 0)
   as value_usd
   from wallets_end b
   join settleton_pools p on p.pool_address = b."owner"
   group by 1
), settleton_balances_before as (
 select ed.address, pool_address, balance from wallets_start b
 join tol.enrollment_degen ed on ed.address = b."owner"
 join settleton_pools on pool_address = b.jetton_master
), settleton_balances_after as (
 select ed.address, pool_address, balance from wallets_end b
 join tol.enrollment_degen ed on ed.address = b."owner"
 join settleton_pools on pool_address = b.jetton_master
), settleton_balances_delta as (
 select address, pool_address, coalesce(settleton_balances_after.balance, 0) - coalesce(settleton_balances_before.balance, 0) as balance_delta
 from settleton_balances_after left join settleton_balances_before using(address, pool_address) 
), settleton_total_supply as (
   select pool_address, sum(balance) as total_supply
   from wallets_end b
   join settleton_pools on pool_address = b.jetton_master
   group by 1
   having sum(balance) > 0
), settleton_index_pools as (
 select p.pool_address, balance * tvls.value_usd / supply.total_supply
   as value_usd
   from wallets_end b
   join settleton_pools p on p.pool_address = b."owner"
   join settleton_pool_tvls tvls on tvls.pool_address = b.jetton_master
   join settleton_total_supply supply on supply.pool_address = tvls.pool_address
--   group by 1
), settleton_pools_tvl_2_flat as (
 select pool_address, value_usd from settleton_pool_tvls
union all
select pool_address, value_usd from settleton_index_pools
), settleton_pools_tvl_2 as (
 select pool_address, sum(value_usd) as value_usd from settleton_pools_tvl_2_flat
 group by 1
), settleton_impact as (
 select address, sum(value_usd * balance_delta / total_supply) as tvl_impact, count(balance_delta), null::bigint as min_utime, null::bigint as max_utime
 from settleton_balances_delta
 join settleton_total_supply using(pool_address)
 join settleton_pools_tvl_2 using(pool_address)
 group by 1
), daolama_tvl as (
select balance * (select price from prices.ton_price where price_ts < 1734433200 order by price_ts desc limit 1) / 1e9 as tvl_usd 
from account_states as2 where hash = (
select account_state_hash_after from transactions where account = upper('0:a4793bce49307006d3f4e97d815fb4c78ff7655faecf8606111ae29f8d6b41f4')
and now < 1734433200
order by now desc limit 1)
), daolama_balances_before as (
 select ed.address, balance from wallets_start b
 join tol.enrollment_degen ed on ed.address = b."owner"
 where b.jetton_master = upper('0:a4793bce49307006d3f4e97d815fb4c78ff7655faecf8606111ae29f8d6b41f4')
), daolama_balances_after as (
 select ed.address, balance from wallets_end b
 join tol.enrollment_degen ed on ed.address = b."owner"
 where b.jetton_master = upper('0:a4793bce49307006d3f4e97d815fb4c78ff7655faecf8606111ae29f8d6b41f4')
), daolama_balances_delta as (
 select address, coalesce(daolama_balances_after.balance, 0) - coalesce(daolama_balances_before.balance, 0) as balance_delta
 from daolama_balances_after left join daolama_balances_before using(address)
), daolama_total_supply as (
   select sum(balance) as total_supply
   from wallets_end b
   where b.jetton_master = upper('0:a4793bce49307006d3f4e97d815fb4c78ff7655faecf8606111ae29f8d6b41f4')
), daolama_impact as (
 select address,
 sum((select tvl_usd from daolama_tvl) * balance_delta / (select total_supply from daolama_total_supply)) as tvl_impact,
 count(balance_delta), null::bigint as min_utime, null::bigint as max_utime
 from daolama_balances_delta
 group by 1
), tonhedge_tvl as (
 select balance / 1e6 as tvl_usd from wallets_end
 where owner = upper('0:57668d751f8c14ab76b3583a61a1486557bd746beeebbd4b2a65418b3fdb5471')
 and jetton_master = '0:B113A994B5024A16719F69139328EB759596C38A25F59028B146FECDC3621DFE'
), tonhedge_balances_before as (
 select ed.address, balance from wallets_start b
 join tol.enrollment_degen ed on ed.address = b."owner"
 where b.jetton_master = upper('0:57668d751f8c14ab76b3583a61a1486557bd746beeebbd4b2a65418b3fdb5471')
), tonhedge_balances_after as (
 select ed.address, balance from wallets_end b
 join tol.enrollment_degen ed on ed.address = b."owner"
 where b.jetton_master = upper('0:57668d751f8c14ab76b3583a61a1486557bd746beeebbd4b2a65418b3fdb5471')
), tonhedge_balances_delta as (
 select address, coalesce(tonhedge_balances_after.balance, 0) - coalesce(tonhedge_balances_before.balance, 0) as balance_delta
 from tonhedge_balances_after left join tonhedge_balances_before using(address)
), tonhedge_total_supply as (
   select sum(balance) as total_supply
   from wallets_end b
   where b.jetton_master = upper('0:57668d751f8c14ab76b3583a61a1486557bd746beeebbd4b2a65418b3fdb5471')
), tonhedge_impact as (
 select address,
  sum((select tvl_usd from tonhedge_tvl) * balance_delta / (select total_supply from tonhedge_total_supply)) as tvl_impact,
  count(balance_delta), null::bigint as min_utime, null::bigint as max_utime
 from tonhedge_balances_delta
 group by 1
), tonpools_operations as (
  select source as address, created_at, value / 1e9 * 
  (select price from prices.ton_price where price_ts < m.created_at order by price_ts desc limit 1) as value_usd
  from messages m where direction ='in' and destination =upper('0:3bcbd42488fe31b57fc184ea58e3181594b33b2cf718500e108411e115978be1')
  and created_at >= 1732705200 and created_at < 1734433200 and opcode = 569292295
   union all
  select m_in.source as address, m_in.created_at, -1 * m_out.value  / 1e9 *
  (select price from prices.ton_price where price_ts < m_out.created_at order by price_ts desc limit 1) as value_usd
  from messages m_in
  join messages m_out on m_out.tx_hash  = m_in.tx_hash and m_out.direction  = 'out'
  join parsed.message_comments mc on mc.hash  = m_out.body_hash 
  where m_in.direction ='in' and m_in.destination =upper('0:3bcbd42488fe31b57fc184ea58e3181594b33b2cf718500e108411e115978be1')
  and m_in.created_at  >= 1732705200 and m_in.created_at < 1734433200 and m_in.opcode = 195467089
  and mc."comment" = 'Withdraw completed'
    union all
  select
  case when destination = upper('0:eb4b3f56e2d8f09eacb5178cfe3b8564769f20d983fde1c9a1d765f945b6297a') then source
  else destination end as address, tx_now as created_at,
  case when source = upper('0:eb4b3f56e2d8f09eacb5178cfe3b8564769f20d983fde1c9a1d765f945b6297a') then -1 else 1 end * amount / 1e6 as value_usd
  from jetton_transfers
  where jetton_master_address = upper('0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe')
  and tx_now >= 1732705200 and tx_now < 1734433200 
  and (
    destination = upper('0:eb4b3f56e2d8f09eacb5178cfe3b8564769f20d983fde1c9a1d765f945b6297a')
  or
    source = upper('0:eb4b3f56e2d8f09eacb5178cfe3b8564769f20d983fde1c9a1d765f945b6297a')
  ) and not tx_aborted
), tonpools_impact as (
 select address, sum(value_usd) as tvl_impact, count(value_usd), min(created_at) as min_utime, max(created_at) as max_utime
 from tonpools_operations group by 1
), parraton_pools as (
  select address as pool_address from jetton_masters jm where 
  admin_address = '0:705A574E176A47C785CCE821E5C1DC551BA65F70E828913EFAEF6DFA648184E6'
), parraton_pool_tvls as (
 select pool_address, 
  coalesce (sum( (select tvl_usd / total_supply from prices.dex_pool_history dph where pool = jetton_master and timestamp < 1734433200 order by timestamp desc limit 1) * balance), 0)
   as value_usd
   from wallets_end b
   join parraton_pools p on p.pool_address = b."owner"
   group by 1
), parraton_balances_before as (
 select ed.address, pool_address, balance from wallets_start b
 join tol.enrollment_degen ed on ed.address = b."owner"
 join parraton_pools on pool_address = b.jetton_master
), parraton_balances_after as (
 select ed.address, pool_address, balance from wallets_end b
 join tol.enrollment_degen ed on ed.address = b."owner"
 join parraton_pools on pool_address = b.jetton_master
), parraton_balances_delta as (
 select address, pool_address, coalesce(parraton_balances_after.balance, 0) - coalesce(parraton_balances_before.balance, 0) as balance_delta
 from parraton_balances_after left join parraton_balances_before using(address, pool_address) 
), parraton_total_supply as (
   select pool_address, sum(balance) as total_supply
   from wallets_end b
   join parraton_pools on pool_address = b.jetton_master
   group by 1
  having sum(balance) > 0
), parraton_impact as (
 select address, sum(value_usd * balance_delta / total_supply) as tvl_impact,
  count(balance_delta), null::bigint as min_utime, null::bigint as max_utime 
 from parraton_balances_delta
 join parraton_total_supply using(pool_address)
 join parraton_pool_tvls using(pool_address)
 group by 1
), tonstable_assets as (
  select 'stTON' as symbol, upper('0:cd872fa7c5816052acdf5332260443faec9aacc8c21cca4d92e7f47034d11892') as jetton_master_address
    union all
  select 'tsTON' as symbol, upper('0:bdf3fa8098d129b54b4f73b5bac5d1e1fd91eb054169c3916dfc8ccd536d1000') as jetton_master_address
    union all
  select 'STAKED' as symbol, upper('0:aa0ba121449feda569e02b12fa755d24e834a7454aecf4649590b6df742aac8f') as jetton_master_address
), tonstable_flow as (
  select 
  case when destination = upper('0:b606de2fc1c4a00b000194e7e097be466c6b82d06a515361ac64aaaa307bbe4f') then source
  else destination end as address,
  case when source = upper('0:b606de2fc1c4a00b000194e7e097be466c6b82d06a515361ac64aaaa307bbe4f') then -1 else 1 end * amount / 1e9 * 
  case when symbol in ('stTON', 'tsTON') then
    coalesce((select price from prices.core where asset = jetton_master_address and price_ts < tx_now order by price_ts desc limit 1), 0) *
    (select price from prices.ton_price where price_ts < tx_now order by price_ts desc limit 1)
  when symbol = 'STAKED' then 
    coalesce((select price_usd from prices.agg_prices 
      where base = jetton_master_address and price_time < tx_now order by price_time desc limit 1), 0) * 1e3 end
  as tvl_usd,
  tx_now
  from jetton_transfers
  join tonstable_assets using (jetton_master_address)
  where tx_now >= 1732705200 and tx_now < 1734433200 
  and (
    destination = upper('0:b606de2fc1c4a00b000194e7e097be466c6b82d06a515361ac64aaaa307bbe4f')
  or
    source = upper('0:b606de2fc1c4a00b000194e7e097be466c6b82d06a515361ac64aaaa307bbe4f')
  ) and not tx_aborted
), tonstable_impact as (
  select address, sum(tvl_usd) as tvl_impact, count(tvl_usd), min(tx_now) as min_utime, max(tx_now) as max_utime
  from tonstable_flow
  group by 1
), aqua_assets as (
  select 'stTON' as symbol, upper('0:cd872fa7c5816052acdf5332260443faec9aacc8c21cca4d92e7f47034d11892') as jetton_master_address
    union all
  select 'tsTON' as symbol, upper('0:bdf3fa8098d129b54b4f73b5bac5d1e1fd91eb054169c3916dfc8ccd536d1000') as jetton_master_address
    union all
  select 'hTON' as symbol, upper('0:cf76af318c0872b58a9f1925fc29c156211782b9fb01f56760d292e56123bf87') as jetton_master_address
    union all
  select 'STAKED' as symbol, upper('0:aa0ba121449feda569e02b12fa755d24e834a7454aecf4649590b6df742aac8f') as jetton_master_address
    union all
  select 'TON-SLP' as symbol, upper('0:8d636010dd90d8c0902ac7f9f397d8bd5e177f131ee2cca24ce894f15d19ceea') as jetton_master_address
    union all
  select 'USDT-SLP' as symbol, upper('0:aea78c710ae94270dc263a870cf47b4360f53cc5ed38e3db502e9e9afb904b11') as jetton_master_address
    union all
  select 'LP TON/USDT' as symbol, upper('0:3e5ffca8ddfcf36c36c9ff46f31562aab51b9914845ad6c26cbde649d58a5588') as jetton_master_address
    union all
  select 'LP tsTON/USDT' as symbol, upper('0:6487b31ce35d564d8174a34f3932dc09a58a6f1a164e301a61848173129ce554') as jetton_master_address
    union all
  select 'LP stTON/USDT' as symbol, upper('0:a6f76cc50642defea7050e9ed606f23a245483b26e166c33ef67bc4d77b9cf2f') as jetton_master_address
), aqua_flow as (
  select 
  case when destination = upper('0:160f2c40452977a25d86d5130b3307a9af7bfa4deaf996cde388096178ab2182') then source
  else destination end as address,
  case when source = upper('0:160f2c40452977a25d86d5130b3307a9af7bfa4deaf996cde388096178ab2182') then -1 else 1 end * amount / 1e9 * 
  case when symbol in ('stTON', 'tsTON', 'hTON', 'TON-SLP') then
    coalesce((select price from prices.core where asset = jetton_master_address and price_ts < tx_now order by price_ts desc limit 1), 1) *
    (select price from prices.ton_price where price_ts < tx_now order by price_ts desc limit 1)
  when symbol = 'USDT-SLP' then 
    coalesce((select price from prices.core where asset = jetton_master_address and price_ts < tx_now order by price_ts desc limit 1), 0)
  when symbol = 'STAKED' then 
    coalesce((select price_usd from prices.agg_prices 
      where base = jetton_master_address and price_time < tx_now order by price_time desc limit 1), 0) * 1e3
  else (select tvl_usd / total_supply * 1e9 from prices.dex_pool_history 
    where pool = jetton_master_address and "timestamp" < tx_now order by "timestamp" desc limit 1) end
  as tvl_usd,
  tx_now
  from jetton_transfers
  join aqua_assets using (jetton_master_address)
  where tx_now  >= 1732705200 and tx_now < 1734433200 
  and (
    destination = upper('0:160f2c40452977a25d86d5130b3307a9af7bfa4deaf996cde388096178ab2182')
  or
    source = upper('0:160f2c40452977a25d86d5130b3307a9af7bfa4deaf996cde388096178ab2182')
  ) and not tx_aborted
), aqua_impact as (
  select address, sum(tvl_usd) as tvl_impact, count(tvl_usd), min(tx_now) as min_utime, max(tx_now) as max_utime
  from aqua_flow
  group by 1
), swapcoffee_pools as (
  select 'CES' as pool_name, '0:29F90533937D696105883B981E9427D1AE411EEF5B08EAB83F4AF89C495D27DF' as pool_address
    union all
  select 'XROCK' as pool_name, '0:C84DEAF1D956D5F80BE722BBDAEEBA33D70D068ACE97C6FC23E1BFEB5689E1CA' as pool_address
), swapcoffee_assets as (
  select 'CES' as pool_name, 'CES' as symbol,
  '0:A5D12E31BE87867851A28D3CE271203C8FA1A28AE826256E73C506D94D49EDAD' as jetton_master_address
    union all
  select 'CES' as pool_name, 'DeDust CES-TON LP' as symbol,
  '0:123E245683BD5E93AE787764EBF22291306F4A3FCBB2DCFCF9E337186AF92C83' as jetton_master_address
    union all
  select 'CES' as pool_name, 'Ston.fi CES-TON LP' as symbol,
  '0:6A839F7A9D6E5303D71F51E3C41469F2C35574179EB4BFB420DCA624BB989753' as jetton_master_address
    union all
  select 'XROCK' as pool_name, 'XROCK' as symbol,
  '0:157C463688A4A91245218052C5580807792CF6347D9757E32F0EE88A179A6549' as jetton_master_address
    union all
  select 'XROCK' as pool_name, 'DeDust XROCK-USDT LP' as symbol,
  '0:9CF96B400DEEDD4143BD113D8D767F0042515E2AD510C4B4ADBE734CD30563B8' as jetton_master_address
    union all
  select 'XROCK' as pool_name, 'Ston.fi XROCK-USDT LP' as symbol,
  '0:6BA0E19F6ADACBEFDCBBC859407241EFF578F4A57EDC8E3E05E86DCFBB283F20' as jetton_master_address
), swapcoffee_flow as (
  select "source" as address,
  case
    when symbol in ('CES', 'XROCK') then
      coalesce((select price_usd from prices.agg_prices ap
      where ap.base = jetton_master_address and price_time < 1734433200 order by price_time desc limit 1) * jt.amount / 1e6, 0)
    else
      coalesce((select jt.amount * tvl_usd / total_supply from prices.dex_pool_history dph
      where pool = jetton_master_address and "timestamp" < 1734433200 order by "timestamp" desc limit 1), 0)
  end as tvl_usd,
  tx_now
  from jetton_transfers jt 
  join swapcoffee_assets sa using(jetton_master_address)
  join swapcoffee_pools sp on sa.pool_name = sp.pool_name and destination = sp.pool_address
  where tx_now >= 1732705200 and tx_now < 1734433200 and not tx_aborted
), swapcoffee_impact as (
  select address, sum(tvl_usd) as tvl_impact, count(tvl_usd), min(tx_now) as min_utime, max(tx_now) as max_utime
  from swapcoffee_flow
  group by 1
), coffin_assets as (
  select 'TON' as symbol,
  '0:1A4219FE5E60D63AF2A3CC7DCE6FEC69B45C6B5718497A6148E7C232AC87BD8A' as asset_id,
  '0:0000000000000000000000000000000000000000000000000000000000000000' as jetton_address
  union all
  select 'USDT' as symbol,
  '0:CA9006BD3FB03D355DAEEFF93B24BE90AFAA6E3CA0073FF5720F8A852C933278' as asset_id,
  '0:B113A994B5024A16719F69139328EB759596C38A25F59028B146FECDC3621DFE' as jetton_address
  union all
  select 'HYDRA' as symbol,
  '0:EC96F4CFD28C381277B7A2A796F0FF91DC8D93ECDDF9C8E8D570473B5900BCDD' as asset_id,
  '0:F83F7D94D74B2736821ABE8ABA7183D3411F367B00233B6D1EA6282B59102EA7' as jetton_address
  union all
  select 'GRAM' as symbol,
  '0:EA9873AB493D0C43D24D89EE1F96080B91521D3C6AE0E0199A673FFEF92E2021' as asset_id,
  '0:B8EF4F77A17E5785BD31BA4DA50ABD91852F2B8FEBEE97AD6EE16D941F939198' as jetton_address
  union all
  select 'ANON' as symbol,
  '0:6E0DB23E574A1AB873107C341EFBC5FA22616D3EECB1CECFAC12B9D22589C203' as asset_id,
  '0:EFFB2AF8D7F099DAEAE0DA07DE8157DAE383C33E320AF45F8C8A510328350886' as jetton_address
  union all
  select 'durev' as symbol,
  '0:5FF06029CA6BABEDB1633E6081A63944086058E3DD3681FDE6F292729B14B096' as asset_id,
  '0:74D8327471D503E2240345B06FE1A606DE1B5E3C70512B5B46791B429DAB5EB1' as jetton_address
  union all
  select 'PEPE' as symbol,
  '0:E63FFAC3F5E5CF4AF7A2C2F5C95C90F20AF44D01F0B02287E7B1445EB1298993' as asset_id,
  '0:97cceec78682b97c342e08e344e3797cf90b2b7aae73abcf5954d8449dadb878' as jetton_address
  union all
  select 'BOLGUR' as symbol,
  '0:5D12CB57CCA228F04A89E10F5629C18A94E8B4180CD2A8D5AB577AA80F7C6290' as asset_id,
  '0:538d1d671a5c537516464921de5d8bdc903919737783c2ea73045873e5c0f1f9' as jetton_address
), coffin_prices as (
  select asset_id, 
  case 
  	when symbol = 'TON' then (select price from prices.ton_price p where p.price_ts < 1734433200 order by price_ts desc limit 1) / 1e3
  	when symbol = 'USDT' then 1
  	else (select price_usd from prices.agg_prices ap 
  	  where ap.base = jetton_address and price_time < 1734433200 order by price_time desc limit 1)
  end as price
  from coffin_assets
), coffin_events as (
  select tx_hash, owner_address as address, asset_id, amount, utime from parsed.evaa_supply es
  where pool_address = '0:68CF02950F26BD20BDCAC38991E40429878CA8D7912E31DC97F272E58DE694C6'
  and utime >= 1732705200 and utime < 1734433200
  union all 
  select tx_hash, owner_address, asset_id, -amount, utime from parsed.evaa_withdraw ew
  where pool_address = '0:68CF02950F26BD20BDCAC38991E40429878CA8D7912E31DC97F272E58DE694C6'
  and utime >= 1732705200 and utime < 1734433200
), coffin_totals as (
  select address, asset_id, sum(amount * price / 1e6) as volume_usd, count(amount), min(utime) as min_utime, max(utime) as max_utime
  from coffin_events
  join coffin_prices using (asset_id)
  group by 1, 2
), coffin_impact as (
  select address, sum(volume_usd) as tvl_impact, count("count"), min(min_utime) as min_utime, max(max_utime) as max_utime
  from coffin_totals
  group by 1
),
-- TONCO
tonco_collections as (
  -- get all NFT pools owner by the router
  select  address from public.nft_collections nc where 
  owner_address ='0:BFFADD270A738531DA7B13BA8FC403826C2586173F9EDE9C316FAB53BC59AC86'
), tonco_positions as (
  -- get all NFT positions which is active now (init=true)
  select address, owner_address from public.nft_items ni 
  where collection_address in (select * from tonco_collections) and init
), tonco_positions_first_tx as (
  -- get first transaction for every NFT position. This tx will be a part of mint tx chain
  -- to get the first transaction we will filter by end_status and orig_status and also filter 
  -- on the season period, so mints out of the season time range will be nulls
  select *, (select trace_id from transactions t where t.account = p.address and orig_status != 'active' 
  and end_status = 'active' 
  and now > 1732705200
  and now < 1734433200
  order by lt asc limit 1) from tonco_positions p
), tonco_jetton_transfers as (
  -- now we need to get all liquidity transfers from the LP owner in the same tx chain (trace_id)
  -- so let's take all successful jetton transfers with the same trace_id
  select p.owner_address, p.trace_id, jt.amount, jt.jetton_master_address, tx_now from public.jetton_transfers jt 
  join tonco_positions_first_tx p on p.trace_id = jt.trace_id and p.owner_address = jt.source
  where p.trace_id is not null -- filter out mints outside of the season time range
  and not jt.tx_aborted
), tonco_jetton_liquidity_transfers as (
  -- estimate liquidity amount in USD
  select owner_address, trace_id, (
  case
  -- special case - USDT, always 1$
  when jetton_master_address = '0:B113A994B5024A16719F69139328EB759596C38A25F59028B146FECDC3621DFE' 
      then 1
    -- for all other jettons let's get latest agg price just before the event
    else (select price_usd from prices.agg_prices ap where 
        ap.base = jetton_master_address and
        price_time < tx_now
        order by price_time desc limit 1)
  end
  ) * amount / 1e6 as amount_usd from tonco_jetton_transfers
), tonco_unique_traces as (
  -- prepare all unique traces
  select distinct owner_address, trace_id from tonco_jetton_liquidity_transfers
), tonco_pton_transfers as (
  -- unfortunately, wrapped TON by TONCO doesn't comply with TEP-74 and it is missing from the previous filter.
  -- so to get it we will extract all 0x01f3835d messages (pTON) from the same tx chain (the same trace_id)
  -- each messages carries some gas amount (~0.5TON) so we will substract it from the message value
  select owner_address, trace_id, 
  (
    select (greatest(0, value - 5e8)) / 1e9 * (select price from prices.ton_price tp where 
      tp.price_ts < m.created_at order by tp.price_ts desc limit 1) 
    as amount_usd  from trace_edges te -- using trace_adges to get all messages
    join messages m  on m.tx_hash  =te.left_tx and direction = 'in'
    where te.trace_id = tonco_unique_traces.trace_id 
  and opcode = 32736093 -- 0x01f3835d
  ) as amount_usd
  from tonco_unique_traces
), tonco_liquidity_transfers as (
  -- combine jettons and TON transfers
  select owner_address, amount_usd from tonco_pton_transfers where amount_usd is not null
  union all
  select owner_address, amount_usd from tonco_jetton_liquidity_transfers where amount_usd is not null
), tonco_impact as (
  -- final calculation of impact
  select owner_address as address, sum(amount_usd) as tvl_impact, count(amount_usd), null::bigint as min_utime, null::bigint as max_utime
  from tonco_liquidity_transfers group by 1
), farmix_pools as (
  select upper('0:be8e55fcdc36198125915b9abf5ee1cb5961503e9db11a673c042a1e59c90aa5') as pool, -- pTON pool
    upper('0:1bb30d579441ffdbc4f3ab248a460cd748e2a9f044dc0d59ba7871da31648268') as jetton,
    (select price from prices.ton_price p where p.price_ts < 1734433200 order by price_ts desc limit 1) / 1e3 as price
  union all
  select upper('0:fa81049609ac8787416f5274d79697e2cc85a2abb51e138818bd7198b4484860') as pool, -- USDT pool
    upper('0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe') as jetton,
    1 as price
  union all
  select upper('0:84ffa4debca1298fc393cf7ad9b750f96d1e9f10d41b48dd9b6d6d23cf16d618') as pool, -- NOT pool
    upper('0:2f956143c461769579baef2e32cc2d7bc18283f40d20bb03e432cd603ac33ffc') as jetton,
    (select price_usd from prices.agg_prices ap 
    where ap.base = upper('0:2f956143c461769579baef2e32cc2d7bc18283f40d20bb03e432cd603ac33ffc') and price_time < 1734433200 
    order by price_time desc limit 1) as price
), farmix_agg_mints as (
  select fp.pool, jt."source" as address, sum(jt.amount) as total_transfer_amount, sum(jm.amount) as total_mint_amount,
    fp.price, count(jm.amount), min(jm.utime) as min_utime, max(jm.utime) as max_utime
  from parsed.jetton_mint jm
  join farmix_pools fp on jetton_master_address = pool
  join jetton_transfers jt on jm.trace_id = jt.trace_id and jt.destination = fp.pool and jt.jetton_master_address = fp.jetton and not jt.tx_aborted
  where jm.utime >= 1732705200 and jm.utime < 1734433200 and jm.successful
  group by fp.pool, jt."source", fp.price
), farmix_agg_burns as (
  select pool, "owner" as address, sum(amount) as total_burn_amount from jetton_burns jb 
  join farmix_pools fp on jetton_master_address = pool
  where tx_now >= 1732705200 and tx_now < 1734433200 and not tx_aborted
  group by pool, "owner"
), farmix_impact as (
  select address,
   sum((total_mint_amount - coalesce(total_burn_amount, 0)) / total_mint_amount * total_transfer_amount * price / 1e6) as tvl_impact,
   count("count"), min(min_utime) as min_utime, max(max_utime) as max_utime
  from farmix_agg_mints
  left join farmix_agg_burns using (pool, address)
  group by 1
), crouton_vaults as (
  select '3TON' as agg_pool, 'TON' as symbol,
  '0:1D5FDACD17489F917240A3B097839BFBF3205B3FD3B52F850BECCF442345CC92' as vault_address,
  '0:0000000000000000000000000000000000000000000000000000000000000000' as jetton_address
    union all
  select '3TON' as agg_pool, 'stTON' as symbol,
  '0:D1A320E2F0B5505B8092F3819D02EBDABD2BA0C683F52C2138F5A7C4A6064CB5' as vault_address,
  '0:CD872FA7C5816052ACDF5332260443FAEC9AACC8C21CCA4D92E7F47034D11892' as jetton_address
    union all
  select '3TON' as agg_pool, 'tsTON' as symbol,
  '0:260820E60D38B53C03BD6711FD333C3B10B2A0223658A320CF856D3BA1272B30' as vault_address,
  '0:BDF3FA8098D129B54B4F73B5BAC5D1E1FD91EB054169C3916DFC8CCD536D1000' as jetton_address
    union all
  select 'USDT' as agg_pool, 'USDT' as symbol,
  '0:79EC163AE7F967F97BF61E9AB3B2D32AA0B2D5160FC464F70ED2DA12F9D2E55C' as vault_address,
  '0:B113A994B5024A16719F69139328EB759596C38A25F59028B146FECDC3621DFE' as jetton_address
    union all
  select 'USDT' as agg_pool, 'DONE' as symbol,
  '0:6667F3B8B2E7F6E0893C064907F9DBE6920A4D9907C941657E88B1A37EA96D28' as vault_address,
  '0:A0194301FEED4692BB24C36A38D3B220F3299099F9315AE3D6D9DE0836E4283C' as jetton_address
    union all
  select 'USDT' as agg_pool, 'AquaUSD' as symbol,
  '0:8CD61774DC5D6478A34A881D8504F753EDE6E9A3420C22F2CCAC0997E9B3BE20' as vault_address,
  '0:160F2C40452977A25D86D5130B3307A9AF7BFA4DEAF996CDE388096178AB2182' as jetton_address
), crouton_pools as (
  select '3TON' as agg_pool, '0:7B3ABBA2D73FDD28E3681EE825BE2D9B314A660F87F0D19E02DA07B00F614FD0' as pool_address
    union all
  select 'USDT' as agg_pool, '0:58C90C9E8379FEE9110984A724CB898AE56A666E085176902CCFE062E5C25751' as pool_address
    union all
  select 'USDT' as agg_pool, '0:79A2C147EA4CC1376CCAF5FDC0D4B6467892A6A9CC8646E99884982DB9695B8C' as pool_address    
), crouton_vaults_tvl as (
  select agg_pool,
  case 
    when symbol = 'TON' then
      (select balance * (select price from prices.ton_price where price_ts < 1734433200 order by price_ts desc limit 1) / 1e9
      from account_states as2 
      where hash = (select account_state_hash_after from transactions where account = vault_address and now < 1734433200 order by now desc limit 1))
    when symbol in ('stTON', 'tsTON') then
      (select balance * (select price_usd from prices.agg_prices ap 
      where ap.base = jetton_address and price_time < 1734433200 order by price_time desc limit 1) / 1e6
      from wallets_end where "owner" = vault_address and jetton_master = jetton_address)
    when symbol = 'DONE' then
      (select balance / 1e9 from wallets_end where "owner" = vault_address and jetton_master = jetton_address)
    else
      (select balance / 1e6 from wallets_end where "owner" = vault_address and jetton_master = jetton_address)
  end as tvl_usd
  from crouton_vaults
), crouton_total_tvl as (
  select agg_pool, sum(tvl_usd) as total_tvl_usd from crouton_vaults_tvl group by agg_pool
), crouton_balances_before as (
  select agg_pool, ed.address, sum(balance) as balance from wallets_start b
  join tol.enrollment_degen ed on ed.address = b."owner"
  join crouton_pools cp on b.jetton_master = cp.pool_address
  group by (agg_pool, ed.address)
), crouton_balances_after as (
  select agg_pool, ed.address, sum(balance) as balance from wallets_end b
  join tol.enrollment_degen ed on ed.address = b."owner"
  join crouton_pools cp on b.jetton_master = cp.pool_address
  group by (agg_pool, ed.address)
), crouton_balances_delta as (
  select agg_pool, address, coalesce(cba.balance, 0) - coalesce(cbb.balance, 0) as balance_delta
  from crouton_balances_after cba 
  left join crouton_balances_before cbb using(agg_pool, address) 
), crouton_total_supply as (
  select agg_pool, sum(balance) as total_supply from wallets_end b
  join crouton_pools cp on b.jetton_master = cp.pool_address
  group by agg_pool
), crouton_impact as (
  select address, sum(total_tvl_usd * balance_delta / total_supply) as tvl_impact,
    count(balance_delta), null::bigint as min_utime, null::bigint as max_utime 
  from crouton_balances_delta
  join crouton_total_supply using(agg_pool)
  join crouton_total_tvl using(agg_pool)
  group by 1
), delea_flow as (
  -- get all mints during the period
  select "owner" as address, amount,
  utime as event_time from parsed.jetton_mint jm
  where jetton_master_address = upper('0:a0194301feed4692bb24c36a38d3b220f3299099f9315ae3d6d9de0836e4283c')
  and utime >= 1732705200 and utime < 1734433200 and successful
  
  union all
  
  -- all transfers to the vaults (repay)
  select "source" as address, -1 * amount as amount,
  tx_now as event_time from public.jetton_transfers jt 
  where jetton_master_address = upper('0:a0194301feed4692bb24c36a38d3b220f3299099f9315ae3d6d9de0836e4283c')
  and tx_now >= 1732705200 and tx_now < 1734433200 and not tx_aborted
  and (
  destination  = upper('0:7aae44bcc6ddc4cb85ee81d56a4037b5bede0a24387cd77fe4d9c7a838d4c206') -- TON vault
  or 
  destination  = upper('0:b020844aa6e57d7d0a50c5d4cc84b00edf430d1dae86398774d13b3248e398b4') -- tsTON vault
    or 
  destination  = upper('0:363b30ae3fcf9dfe5376318c4bbf958235fa4b1f5354bae829a4e6416603589f') -- stTON vault
  )
), delea_price as (
  -- DONE is a stablecoin, but it is more reliable to get price from DEX trades
  select coalesce((select price_usd from prices.agg_prices ap where ap.base = upper('0:a0194301feed4692bb24c36a38d3b220f3299099f9315ae3d6d9de0836e4283c')
  and price_time < 1734433200 order by price_time desc limit 1), 0) as price
), delea_impact as (
  -- final user impact - sum of all mints and repays (with negative value of the amount) converted to USD using DEX price
  select address, sum(amount) * (select price from delea_price) / 1e6 as tvl_impact, count(1), min(event_time) as min_utime, max(event_time) as max_utime
  from delea_flow
  group by 1
), beetroot_flow as (
select "owner" as address, amount,
  -- all mints
  utime as event_time from parsed.jetton_mint jm
  where jetton_master_address = upper('0:051a19b1d7df681fa9262fbf0f1811f2031e1de4288975f5f04a30cae45e4817')
  and utime >= 1732705200 and utime < 1734433200 and successful
  
  union all
  
  -- transfers to the smart contract to withdraw funds
  select "source" as address, -1 * amount as amount,
  tx_now as event_time from public.jetton_transfers jt 
  where jetton_master_address =  upper('0:051a19b1d7df681fa9262fbf0f1811f2031e1de4288975f5f04a30cae45e4817')
  and tx_now >= 1732705200 and tx_now < 1734433200 and not tx_aborted
  and destination  = upper('0:c2f0c639b58e6b3cce8a145c73e7c7cc5044baa92b05c62fcf6da8a0d50b8edc')
), beetroot_tvl as (
  select 
  -- Storm SLP balance of the protocol
  (select balance from wallets_end where owner = upper('0:c2f0c639b58e6b3cce8a145c73e7c7cc5044baa92b05c62fcf6da8a0d50b8edc')
  and jetton_master = upper('0:aea78c710ae94270dc263a870cf47b4360f53cc5ed38e3db502e9e9afb904b11')
  )
  * 
  -- SLP price: SLP/USDT
  (select price from prices.core c where asset = upper('0:aea78c710ae94270dc263a870cf47b4360f53cc5ed38e3db502e9e9afb904b11')
  order by price_ts desc limit 1) / 1e9

  + 

  -- Tradoor LP balance of the protocol
  (select balance from wallets_end where owner = upper('0:c2f0c639b58e6b3cce8a145c73e7c7cc5044baa92b05c62fcf6da8a0d50b8edc')
  and jetton_master = upper('0:332c916f885a26051cb3a121f00c2bda459339eb103df36fe484df0b87b39384')
  )
  * 
  -- Tradoor vault USDT balance
  (select balance from wallets_end jw where owner = upper('0:ff1338c9f6ed1fa4c264a19052bff64d10c8ad028628f52b2e0f4b357a12227e')
  and jetton_master = upper('0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe')
  )
  /
  -- Tradoor total supply
  (
  select sum(balance) from wallets_end where jetton_master = upper('0:332c916f885a26051cb3a121f00c2bda459339eb103df36fe484df0b87b39384')
  ) / 1e6

  as tvl
), beetroot_supply as (
  select sum(balance) as supply from wallets_end where jetton_master = upper('0:051a19b1d7df681fa9262fbf0f1811f2031e1de4288975f5f04a30cae45e4817')
), beetroot_impact as (
  select address, sum(amount) * (select tvl from beetroot_tvl) / (select supply from beetroot_supply) as tvl_impact, count(1), min(event_time) as min_utime, max(event_time) as max_utime
  from beetroot_flow
  group by 1
)
, all_projects_impact as (
 select 'jVault' as project, *, floor(tvl_impact / 20.) * 5 as points from jvault_impact
   union all
 select 'SettleTon' as project, *, floor(tvl_impact / 20.) * 10 as points from settleton_impact
   union all
 select 'DAOLama' as project, *, floor(tvl_impact / 20.) * 10 as points from daolama_impact
   union all
 select 'TONHedge' as project, *, floor(tvl_impact / 20.) * 10 as points from tonhedge_impact
   union all
 select 'TONPools' as project, *, floor(tvl_impact / 20.) * 5 as points from tonpools_impact
   union all
 select 'Parraton' as project, *, floor(tvl_impact / 20.) * 10 as points from parraton_impact
   union all
 select 'TONStable' as project, *, floor(tvl_impact / 20.) * 10 as points from tonstable_impact
   union all
 select 'Aqua' as project, *, floor(tvl_impact / 20.) * 10 as points from aqua_impact
   union all
 select 'swap.coffee staking' as project, *, floor(tvl_impact / 20.) * 5 as points from swapcoffee_impact
   union all
 select 'Coffin' as project, *, floor(tvl_impact / 20.) * 5 as points from coffin_impact
   union all
 select 'TONCO' as project, *, floor(tvl_impact / 20.) * 10 as points from tonco_impact
   union all
 select 'Farmix' as project, *, floor(tvl_impact / 20.) * 10 as points from farmix_impact
   union all
 select 'Crouton' as project, *, floor(tvl_impact / 20.) * 10 as points from crouton_impact
   union all
 select 'Delea' as project, *, floor(tvl_impact / 20.) * 10 as points from delea_impact
   -- union all
 -- select 'Beetroot' as project, *, floor(tvl_impact / 20.) * 10 as points from beetroot_impact
)
select extract(epoch from now())::integer as score_time, p.address, project, points, tvl_impact as "value", "count", min_utime, max_utime
from all_projects_impact p
join tol.enrollment_degen ed on ed.address = p.address