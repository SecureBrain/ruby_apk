# ChangeLog
## 0.7.0
* implement Apk#signs, Apk#certificates and Manifest#version_name (#14, #15)
* bugfix

## 0.6.0
* implement Android::Apk#layouts(#10), Android::Apk#icon(#11), Android::Apk#label(#12),
* fix bug (#13)

## 0.5.1
* [#8] add Android::Manifest#label
* [#7] fix wrong boolean value in manifest parser
* [#6] add accessor Android::Manifest#doc

## 0.5.0
* [issue #1] implement Android::Resource#find, #res_readable_id, #res_hex_id methods

## 0.4.2
* fix bugs(#2, #3)
* divide change log from readme

## 0.4.1
* fix typo
* add document

## 0.4.0
* add resource parser
* enhance dex parser

## 0.3.0
* add and change name space
* add Android::Utils module and some util methods
* add Apk#entry, Apk#each_entry, and Apk#time methods,

## 0.2.0
* update documents
* add Apk::Dex#each_strings, Apk::Dex#each_class_names

## 0.1.2
* fix bug(improve android binary xml parser)

## 0.1.1
* fix bug(failed to initialize Apk::Manifest::Meta class)
* replace iconv to String#encode(for ruby1.9)

