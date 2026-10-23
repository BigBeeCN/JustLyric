#!/usr/bin/perl
# MediaRemoteAdapter 宿主脚本（S7 D37：Apple 平台二进制宿主 + DynaLoader + JSON over stdout）
# 原创实现；用法: perl adapter-host.pl <dylib> <bootstrap|probe|get_sync|loop>
use strict;
use warnings;
use DynaLoader;
$| = 1;
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

die "usage: $0 <dylib> <command>\n" unless @ARGV >= 2;
my ($dylib, $command) = @ARGV;
die "dylib not found: $dylib\n" unless -e $dylib;

my $lib = DynaLoader::dl_load_file($dylib) or die "load: " . DynaLoader::dl_error();
sub inst {
    my ($n) = @_;
    my $s = DynaLoader::dl_find_symbol($lib, "_$n") // DynaLoader::dl_find_symbol($lib, $n);
    die "no symbol: $n\n" unless $s;
    DynaLoader::dl_install_xsub("main::$n", $s);
}
inst("bootstrap"); inst("probe"); inst("get_sync"); inst("get_json"); inst("loop");

if ($command eq "bootstrap") {
    bootstrap();
    print "{\"type\":\"bootstrap\"}\n";
} elsif ($command eq "probe") {
    bootstrap();
    print "{\"type\":\"probe\",\"ok\":" . (probe() ? "true" : "false") . "}\n";
} elsif ($command eq "get_sync" || $command eq "get_json") {
    bootstrap();
    get_json();
} elsif ($command eq "loop") {
    bootstrap();
    print "{\"type\":\"probe\",\"ok\":" . (probe() ? "true" : "false") . "}\n";
    loop();
} else {
    die "unknown command: $command\n";
}
select(undef, undef, undef, 0.05) if $command ne "loop";
