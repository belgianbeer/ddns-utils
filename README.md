# ddns-utils

DNS Dynamic Update（RFC 2136）を使って、組織のDNSレコードを登録・削除するためのユーティリティ集です。

[English version](#english)

## 概要

ホストの追加や削除のたびにゾーンファイルを編集し、SOAのシリアルを更新して、権威サーバーをリロードするのは手間がかかります。しかも正引き（Aレコード）と逆引き（PTRレコード）の両方について同じ作業が必要です。

ddns-utilsは、ホスト名とIPアドレスから生成できるレコードは機械的に生成してしまおう、という考え方のシェルスクリプトです。`nsupdate`経由でDynamic Updateを行うため、ゾーンファイルの編集もSOAシリアルの管理も不要になります。

もともと小さなネットワークでの利用を想定したツールです（「制限事項」参照）。

## 特徴

- ホストの登録では、AレコードとPTRレコードをまとめて登録・更新します
- ホスト名から対象ゾーンを、IPアドレスから対象の逆引きゾーンを、設定をもとに自動で判定します
- ゾーンやネットワークの情報は設定ファイル `ddns.conf` に分離されているため、対象を追加してもプログラムの修正は不要です
- TSIGによる署名（アップデート用・ゾーン転送用）に対応します（使わない場合は設定を省略できます）
- 本体は単一のシェルスクリプトで、他のコマンドは本体へのシンボリックリンクです。bashやzshには依存しません

## コマンド一覧

| コマンド | 説明 |
| --- | --- |
| `ddns-add` | ホストのAレコードとPTRレコードを登録（または更新）する |
| `ddns-del` | ホストのAレコードとPTRレコードを削除する |
| `ddns-zone` | ゾーンの内容をゾーン転送（AXFR）で表示する |
| `ddns-hosts` | ゾーン内のIPアドレスとホスト名の一覧を /etc/hosts 形式で表示する |
| `ddns-backup` | 管理対象の全ゾーンの内容をカレントディレクトリにファイルとして保存する |

`ddns-add` がプログラム本体で、他はすべて `ddns-add` へのシンボリックリンクです。実行時のコマンド名によって動作が切り替わります。シンボリックリンクは `make` で作成します。

## 動作環境

- `/bin/sh` で動作するシェルスクリプトです（FreeBSDのsh、Linuxのdash/ash等を想定）
- 以下の外部コマンドを使用します
  - `dig`、`nsupdate`、`arpaname`（BINDのユーティリティ）
  - `sort`（`ddns-hosts`等でGNU sortの `--version-sort` を使用します）

## インストール

```sh
git clone https://github.com/belgianbeer/ddns-utils.git
cd ddns-utils
make            # ddns-del, ddns-zone, ddns-hosts, ddns-backup のシンボリックリンクを作成
cp ddns.conf-sample ddns.conf
vi ddns.conf    # 自分の環境に合わせて編集
```

スクリプトと設定ファイル `ddns.conf` は**同じディレクトリ**に置いてください。管理者が自分の `~/bin` などに置いて使うことを想定しています。TSIGキーのファイルも含め、アクセス権の設定には注意してください。

## 設定

### ddns.conf

設定は、スクリプトと同じディレクトリにある `ddns.conf` にシェル変数として記述します。また、`ddns-<ホスト名>.conf`（ホスト名はドメイン部分を除いたもの）というファイルがあれば、そちらも追加で読み込まれます。

管理対象を列挙する変数が2つあります。

| 変数 | 説明 |
| --- | --- |
| `db_zone_list` | 管理対象の正引きゾーンのキーワードを空白区切りで列挙 |
| `db_ipv4_list` | 管理対象の逆引き（IPv4ネットワーク）のキーワードを空白区切りで列挙 |

そして、各ゾーンについて1つあたり5つの変数を設定します。

| 変数 | 説明 |
| --- | --- |
| `KEYWORD_zone` | 対象のゾーン名 |
| `KEYWORD_nsvr` | そのゾーンを管理している権威サーバー |
| `KEYWORD_dttl` | デフォルトのTTL（秒） |
| `KEYWORD_keyu` | Dynamic Update用TSIGキーのファイル（省略可） |
| `KEYWORD_keyt` | ゾーン転送（AXFR）用TSIGキーのファイル（省略可） |

`KEYWORD` の決め方は次のとおりです。

- ドメイン名（正引き）の場合：ドメイン名の `.` を `_` に置き換えます
  - 例：`example.jp` → `example_jp`
- IPアドレス（逆引き）の場合：ネットワークアドレスの `.` を `_` に置き換えて、先頭に `ipv4_` を付けます
  - 例：`192.168.37.0/24` → `ipv4_192_168_37`、`172.23.0.0/16` → `ipv4_172_23`

### 設定例

```sh
db_zone_list="
	example_jp
	example_org
"

db_ipv4_list="
	ipv4_192_168_37
	ipv4_172_23
"

example_jp_zone=example.jp
example_jp_nsvr=ns0.example.jp
example_jp_dttl=86400
example_jp_keyu=~/.tsig/example.jp-update.key
example_jp_keyt=~/.tsig/example-transfer.key

example_org_zone=example.org
example_org_nsvr=ns0.example.jp
example_org_dttl=86400
example_org_keyu=~/.tsig/example.org-update.key
example_org_keyt=~/.tsig/example-transfer.key

ipv4_192_168_37_zone=37.168.192.in-addr.arpa
ipv4_192_168_37_nsvr=ns0.example.jp
ipv4_192_168_37_dttl=86400
ipv4_192_168_37_keyu=~/.tsig/ipaddress-update.key
ipv4_192_168_37_keyt=~/.tsig/example-transfer.key

ipv4_172_23_zone=23.172.in-addr.arpa
ipv4_172_23_nsvr=ns0.example.jp
ipv4_172_23_dttl=86400
ipv4_172_23_keyu=~/.tsig/ipaddress-update.key
ipv4_172_23_keyt=~/.tsig/example-transfer.key
```

リポジトリには `ddns.conf-sample` も収録されています。

## 使い方

### 共通オプション

すべてのコマンドで次のオプションが指定できます（実際の動作に影響するのは、更新を行う `ddns-add` と `ddns-del` です）。

| オプション | 説明 |
| --- | --- |
| `-n` | テストモード。`nsupdate` を実行せず、実行内容（nsupdateへの入力）を表示するだけにします |
| `-q` | 静粛モード。デフォルトでは表示される nsupdate への入力を表示しません |

### ddns-add — ホストの登録・更新

```
ddns-add [-nq] [-a] [-t ttl] name ipaddr
```

- `name` のAレコードを登録し、対応するPTRレコードも登録します
- `name` が登録済みの場合は、既存のAレコードと、それを指しているPTRレコードを削除してから登録し直します。つまりデフォルトの動作は「新規登録またはIPアドレスの変更」です
- IPアドレスが管理対象ネットワークに属していない場合、PTRレコードは登録されません（Aレコードだけが登録されます）

| オプション | 説明 |
| --- | --- |
| `-a` | 既存レコードの削除を行いません。同じホスト名に2つ目のIPアドレスを追加する場合などに使います |
| `-t ttl` | 登録するレコードのTTLを秒単位で指定します。省略した場合は、そのゾーンの `KEYWORD_dttl` が使われます |

使用例：

```sh
# 新規登録（AとPTRの両方）
ddns-add obs1.example.jp 192.168.37.10

# IPアドレスの変更（旧レコードは自動で削除されます）
ddns-add obs1.example.jp 192.168.37.20

# 2つ目のIPアドレスを追加（既存レコードを消さない）
ddns-add -a obs1.example.jp 192.168.37.11

# TTLを指定して登録
ddns-add -t 3600 obs1.example.jp 192.168.37.10

# 実行内容だけを確認（実際には更新しない）
ddns-add -n obs1.example.jp 192.168.37.10
```

実行すると、デフォルトでは次のような `nsupdate` への入力が表示されてから送信されます。

```
server ns0.example.jp
zone example.jp
update add	obs1.example.jp.	86400	IN	A	192.168.37.10
send
server ns0.example.jp
zone 37.168.192.in-addr.arpa
update add	10.37.168.192.in-addr.arpa.	86400	IN	PTR	obs1.example.jp.
send
```

### ddns-del — ホストの削除

```
ddns-del [-nq] name
```

- `name` のAレコードと、それを指しているPTRレコードを削除します
- `name` が登録されていない場合はエラーになります
- 管理対象外ネットワークのPTRレコードは削除できません

```sh
ddns-del obs1.example.jp
```

### ddns-zone — ゾーンの表示

```
ddns-zone [-nq] name
```

ゾーン転送（AXFR）でゾーンの内容をそのまま表示します。引数にはドメイン名かネットワークアドレスを指定します。

```sh
ddns-zone example.jp
ddns-zone 192.168.37.0
```

### ddns-hosts — ホスト一覧の表示

```
ddns-hosts zone
```

ゾーン内のAレコード（またはPTRレコード）をもとに、「IPアドレス ホスト名」の一覧を /etc/hosts のような形式で表示します。

```sh
$ ddns-hosts example.jp
127.0.0.1	ns0.example.jp
192.168.37.100	obs100.example.jp
192.168.37.101	obs101.example.jp
```

### ddns-backup — ゾーンのバックアップ

```
ddns-backup
```

管理対象の全ゾーン（正引き・逆引き）をゾーン転送で取得し、カレントディレクトリにゾーン名のファイルとして保存します。

```sh
$ ls
$ ddns-backup
$ ls
23.172.in-addr.arpa       example.jp
37.168.192.in-addr.arpa	  example.org
```

## 制限事項

- **小さなネットワーク向けです。** レコードの削除時などにゾーン転送を利用しているため、ゾーンデータが大きいと転送の時間と負荷が無視できなくなります。RR数が数千個程度であれば実用上問題ありませんが、1万を超えるようなゾーンには向かないと思われます。また、対象ゾーンの判定は順次検索しているため、ゾーン数が非常に多い場合も厳しくなります
- **IPv6には対応していません**（正引き・逆引きともIPv4のみです）
- /24より小さい割り当てに対する逆引き（RFC 2317方式）には汎用的に対応していません。そのような場合は正引きは `ddns-add`、逆引きは `nsupdate` を直接使ってください
- SOAやNS、TXTなど、AとPTR以外のレコードの編集は対象外です。それらを変更したい場合は `nsupdate` を直接使ってください

## 発表資料

本ツールについて発表した資料（日本語）があります。

- 民田 雅人「小さなネットワークのお手軽DNS管理ツール」DNS Summer Day 2025（2025-06-27）
  - https://www.dnsops.jp/event/20250627/20250627_minda.pdf

## ライセンス

2-clause BSD Licenseです。本文は [LICENSE](LICENSE) を参照してください。

Copyright (c) 2016-2026 Masato Minda

---

## English

# ddns-utils (English)

Utilities to maintain your organization's DNS records using DNS Dynamic Update (RFC 2136).

## Overview

Editing a zone file, bumping the SOA serial, and reloading the authoritative server every time a host is added or removed is tedious work — and it has to be done twice, for both forward (A) and reverse (PTR) records.

ddns-utils is a set of shell scripts built on a simple idea: records that can be generated mechanically from a host name and an IP address should be generated mechanically. Updates are sent with `nsupdate` via Dynamic Update, so there is no zone file editing and no SOA serial management.

The tools are intended for small networks (see "Limitations").

## Features

- Registering a host registers (or updates) both its A record and its PTR record together
- The target zone is determined from the host name, and the target reverse zone from the IP address, based on the configuration
- Zone and network information lives in the configuration file `ddns.conf`, so adding new zones or networks does not require changing the program
- TSIG signing is supported, both for updates and for zone transfers (the settings can be omitted if you do not use TSIG)
- The implementation is a single shell script; the other commands are symbolic links to it. It does not depend on bash or zsh

## Commands

| Command | Description |
| --- | --- |
| `ddns-add` | Register (or update) a host's A and PTR records |
| `ddns-del` | Delete a host's A and PTR records |
| `ddns-zone` | Show the contents of a zone via zone transfer (AXFR) |
| `ddns-hosts` | List IP addresses and host names in a zone, in /etc/hosts style |
| `ddns-backup` | Save the contents of all managed zones to files in the current directory |

`ddns-add` is the program itself; all other commands are symbolic links to `ddns-add`, and the behavior is selected by the command name. The symbolic links are created by `make`.

## Requirements

- A shell script that runs under `/bin/sh` (such as FreeBSD's sh or Linux's dash/ash)
- The following external commands:
  - `dig`, `nsupdate`, and `arpaname` (BIND utilities)
  - `sort` (`ddns-hosts` and others use GNU sort's `--version-sort`)

## Installation

```sh
git clone https://github.com/belgianbeer/ddns-utils.git
cd ddns-utils
make            # create the ddns-del, ddns-zone, ddns-hosts and ddns-backup symlinks
cp ddns.conf-sample ddns.conf
vi ddns.conf    # edit it for your environment
```

The scripts and the configuration file `ddns.conf` must be placed in the **same directory**. The tools are meant to be run by an administrator, for example from their own `~/bin`. Take care with the access permissions, including those of the TSIG key files.

## Configuration

### ddns.conf

Configuration is written as shell variables in `ddns.conf`, in the same directory as the scripts. If a file named `ddns-<hostname>.conf` (where `<hostname>` is the host name without the domain part) also exists, it is read in addition.

Two variables list what is managed:

| Variable | Description |
| --- | --- |
| `db_zone_list` | Space-separated list of keywords for the managed forward zones |
| `db_ipv4_list` | Space-separated list of keywords for the managed reverse (IPv4 network) zones |

For each zone, five variables are set:

| Variable | Description |
| --- | --- |
| `KEYWORD_zone` | The zone name |
| `KEYWORD_nsvr` | The authoritative server for the zone |
| `KEYWORD_dttl` | The default TTL, in seconds |
| `KEYWORD_keyu` | TSIG key file for Dynamic Updates (optional) |
| `KEYWORD_keyt` | TSIG key file for zone transfers (AXFR) (optional) |

The `KEYWORD` is derived as follows:

- For a domain name (forward lookup): replace each `.` in the domain name with `_`
  - Example: `example.jp` → `example_jp`
- For an IP address (reverse lookup): replace each `.` in the network address with `_` and prefix it with `ipv4_`
  - Example: `192.168.37.0/24` → `ipv4_192_168_37`, `172.23.0.0/16` → `ipv4_172_23`

### Example configuration

```sh
db_zone_list="
	example_jp
	example_org
"

db_ipv4_list="
	ipv4_192_168_37
	ipv4_172_23
"

example_jp_zone=example.jp
example_jp_nsvr=ns0.example.jp
example_jp_dttl=86400
example_jp_keyu=~/.tsig/example.jp-update.key
example_jp_keyt=~/.tsig/example-transfer.key

example_org_zone=example.org
example_org_nsvr=ns0.example.jp
example_org_dttl=86400
example_org_keyu=~/.tsig/example.org-update.key
example_org_keyt=~/.tsig/example-transfer.key

ipv4_192_168_37_zone=37.168.192.in-addr.arpa
ipv4_192_168_37_nsvr=ns0.example.jp
ipv4_192_168_37_dttl=86400
ipv4_192_168_37_keyu=~/.tsig/ipaddress-update.key
ipv4_192_168_37_keyt=~/.tsig/example-transfer.key

ipv4_172_23_zone=23.172.in-addr.arpa
ipv4_172_23_nsvr=ns0.example.jp
ipv4_172_23_dttl=86400
ipv4_172_23_keyu=~/.tsig/ipaddress-update.key
ipv4_172_23_keyt=~/.tsig/example-transfer.key
```

A sample is also provided in the repository as `ddns.conf-sample`.

## Usage

### Common options

All commands accept the following options (they affect the behavior of the updating commands, `ddns-add` and `ddns-del`):

| Option | Description |
| --- | --- |
| `-n` | Test mode: do not run `nsupdate`; only show what would be sent to it |
| `-q` | Quiet mode: do not show the input to `nsupdate`, which is shown by default |

### ddns-add — Register or update a host

```
ddns-add [-nq] [-a] [-t ttl] name ipaddr
```

- Registers an A record for `name`, together with the corresponding PTR record
- If `name` is already registered, the existing A record and any PTR records pointing to it are deleted first, and then the new records are registered. In other words, the default behavior is "register a new address, or change the address"
- If the IP address does not belong to a managed network, no PTR record is registered (only the A record is)

| Option | Description |
| --- | --- |
| `-a` | Do not delete existing records. Use this to add a second IP address to the same host name, for example |
| `-t ttl` | Specify the TTL, in seconds, of the records to be registered. If omitted, the zone's `KEYWORD_dttl` is used |

Examples:

```sh
# Register a new host (both A and PTR)
ddns-add obs1.example.jp 192.168.37.10

# Change the IP address (the old records are deleted automatically)
ddns-add obs1.example.jp 192.168.37.20

# Add a second IP address (without deleting the existing records)
ddns-add -a obs1.example.jp 192.168.37.11

# Register with a specific TTL
ddns-add -t 3600 obs1.example.jp 192.168.37.10

# Show what would be done, without actually updating
ddns-add -n obs1.example.jp 192.168.37.10
```

By default, the input given to `nsupdate` is shown before it is sent:

```
server ns0.example.jp
zone example.jp
update add	obs1.example.jp.	86400	IN	A	192.168.37.10
send
server ns0.example.jp
zone 37.168.192.in-addr.arpa
update add	10.37.168.192.in-addr.arpa.	86400	IN	PTR	obs1.example.jp.
send
```

### ddns-del — Delete a host

```
ddns-del [-nq] name
```

- Deletes the A record for `name` and any PTR records pointing to it
- It is an error if `name` is not registered
- PTR records in networks that are not managed cannot be deleted

```sh
ddns-del obs1.example.jp
```

### ddns-zone — Show a zone

```
ddns-zone [-nq] name
```

Shows the contents of a zone, as obtained by zone transfer (AXFR). The argument is a domain name or a network address.

```sh
ddns-zone example.jp
ddns-zone 192.168.37.0
```

### ddns-hosts — List hosts in a zone

```
ddns-hosts zone
```

Lists "IP address, host name" pairs in the style of /etc/hosts, based on the A records (or PTR records) in the zone.

```sh
$ ddns-hosts example.jp
127.0.0.1	ns0.example.jp
192.168.37.100	obs100.example.jp
192.168.37.101	obs101.example.jp
```

### ddns-backup — Back up zones

```
ddns-backup
```

Fetches all managed zones (forward and reverse) by zone transfer and saves each one to a file named after the zone in the current directory.

```sh
$ ls
$ ddns-backup
$ ls
23.172.in-addr.arpa       example.jp
37.168.192.in-addr.arpa	  example.org
```

## Limitations

- **Intended for small networks.** Zone transfers are used, for example when deleting records, so if a zone is large, the transfer time and load can no longer be ignored. A zone with a few thousand RRs is fine in practice, but the tools are not suited to zones with more than about 10,000 RRs. The target zone is also found by a sequential search, so a very large number of zones can become a problem
- **IPv6 is not supported** (both forward and reverse lookups are IPv4 only)
- Reverse lookups for allocations smaller than a /24 (RFC 2317 style) are not supported in a general way. In that case, use `ddns-add` for the forward records and `nsupdate` directly for the reverse records
- Records other than A and PTR, such as SOA, NS, or TXT, are out of scope. Use `nsupdate` directly to change those

## Presentation

A presentation about this tool (in Japanese) is available:

- Masato Minda, "An easy DNS management tool for small networks" (in Japanese), DNS Summer Day 2025 (2025-06-27)
  - https://www.dnsops.jp/event/20250627/20250627_minda.pdf

## License

The 2-clause BSD License. See [LICENSE](LICENSE) for the full text.

Copyright (c) 2016-2026 Masato Minda
