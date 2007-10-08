use inc::Module::Install;

name     'Bot-Net';
all_from 'lib/Bot/Net.pm';

requires 'App::CLI';
requires 'App::CLI::Command';
requires 'App::CLI::Command::Help';
requires 'Class::Accessor::Fast';
requires 'Class::Data::Inheritable';
requires 'Data::Remember'           => 0.05;
requires 'File::Find::Rule';
requires 'Hash::Merge';
requires 'Log::Log4perl';
requires 'POE';
requires 'POE::Declarative'         => 0.005;
requires 'POE::Declarative::Mixin';
requires 'Readonly';
requires 'Regexp::Common';
requires 'UNIVERSAL::require';
requires 'YAML::Syck';

no_index directory => qw{ examples };

install_script('bin/botnet');

auto_install;
WriteMakefile;