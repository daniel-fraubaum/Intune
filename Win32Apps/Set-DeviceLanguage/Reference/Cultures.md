# 🌐 Cultures

All specific cultures (language plus region, for example `de-AT`) you can use for `-Culture`, taken from the Windows Language Code Identifier reference.

Source: [[MS-LCID]: Windows Language Code Identifier (LCID) Reference](https://learn.microsoft.com/openspecs/windows_protocols/ms-lcid/), table in [Appendix A: Product Behavior](https://learn.microsoft.com/openspecs/windows_protocols/ms-lcid/a9eac961-e77d-41a6-90a5-ce1a8b0cdb9c) (Microsoft Learn)  
Retrieved: 2026-11-18  
Back to the [README](../README.md)

> Any of these cultures works as regional format (date, time, numbers, currency), independent of the display language.
>
> LCID `0x1000` means the culture has no permanent LCID of its own, see [Locale Names without LCIDs](https://learn.microsoft.com/openspecs/windows_protocols/ms-lcid/926e694f-1797-4418-a922-343d1c5e91a6). Use the tag, not the LCID.

## Check on a device

```powershell
[System.Globalization.CultureInfo]::GetCultures("SpecificCultures") | Select-Object Name, DisplayName
```

## Specific cultures

580 cultures, sorted by tag. Neutral cultures (language only, for example `de`) and sort variants are not listed.

| Language | Location | Tag | LCID hex |
|---|---|---|---|
| Afar | Djibouti | aa-DJ | 0x1000 |
| Afar | Eritrea | aa-ER | 0x1000 |
| Afar | Ethiopia | aa-ET | 0x1000 |
| Afrikaans | Namibia | af-NA | 0x1000 |
| Afrikaans | South Africa | af-ZA | 0x0436 |
| Aghem | Cameroon | agq-CM | 0x1000 |
| Akan | Ghana | ak-GH | 0x1000 |
| Amharic | Ethiopia | am-ET | 0x045E |
| Arabic | World | ar-001 | 0x1000 |
| Arabic | U.A.E. | ar-AE | 0x3801 |
| Arabic | Bahrain | ar-BH | 0x3C01 |
| Arabic | Djibouti | ar-DJ | 0x1000 |
| Arabic | Algeria | ar-DZ | 0x1401 |
| Arabic | Egypt | ar-EG | 0x0c01 |
| Arabic | Eritrea | ar-ER | 0x1000 |
| Arabic | Israel | ar-IL | 0x1000 |
| Arabic | Iraq | ar-IQ | 0x0801 |
| Arabic | Jordan | ar-JO | 0x2C01 |
| Arabic | Comoros | ar-KM | 0x1000 |
| Arabic | Kuwait | ar-KW | 0x3401 |
| Arabic | Lebanon | ar-LB | 0x3001 |
| Arabic | Libya | ar-LY | 0x1001 |
| Arabic | Morocco | ar-MA | 0x1801 |
| Arabic | Mauritania | ar-MR | 0x1000 |
| Arabic | Oman | ar-OM | 0x2001 |
| Arabic | Palestinian Authority | ar-PS | 0x1000 |
| Arabic | Qatar | ar-QA | 0x4001 |
| Arabic | Saudi Arabia | ar-SA | 0x0401 |
| Arabic | Sudan | ar-SD | 0x1000 |
| Arabic | Somalia | ar-SO | 0x1000 |
| Arabic | South Sudan | ar-SS | 0x1000 |
| Arabic | Syria | ar-SY | 0x2801 |
| Arabic | Chad | ar-TD | 0x1000 |
| Arabic | Tunisia | ar-TN | 0x1C01 |
| Arabic | Yemen | ar-YE | 0x2401 |
| Mapudungun | Chile | arn-CL | 0x047A |
| Assamese | India | as-IN | 0x044D |
| Asu | Tanzania | asa-TZ | 0x1000 |
| Asturian | Spain | ast-ES | 0x1000 |
| Azerbaijani (Cyrillic) | Azerbaijan | az-Cyrl-AZ | 0x082C |
| Azerbaijani (Latin) | Azerbaijan | az-Latn-AZ | 0x042C |
| Bashkir | Russia | ba-RU | 0x046D |
| Basaa | Cameroon | bas-CM | 0x1000 |
| Belarusian | Belarus | be-BY | 0x0423 |
| Bemba | Zambia | bem-ZM | 0x1000 |
| Bena | Tanzania | bez-TZ | 0x1000 |
| Bulgarian | Bulgaria | bg-BG | 0x0402 |
| Haryanvi (Devanagari) | India | bgc-Deva-IN | 0x1000 |
| Bhojpuri (Devanagari) | India | bho-Deva-IN | 0x1000 |
| Bamanankan (Latin) | Mali | bm-Latn-ML | 0x1000 |
| Bangla | Bangladesh | bn-BD | 0x0845 |
| Bangla | India | bn-IN | 0x0445 |
| Tibetan | People's Republic of China | bo-CN | 0x0451 |
| Tibetan | India | bo-IN | 0x1000 |
| Breton | France | br-FR | 0x047E |
| Bodo | India | brx-IN | 0x1000 |
| Bosnian (Cyrillic) | Bosnia and Herzegovina | bs-Cyrl-BA | 0x201A |
| Bosnian (Latin) | Bosnia and Herzegovina | bs-Latn-BA | 0x141A |
| Blin | Eritrea | byn-ER | 0x1000 |
| Catalan | Andorra | ca-AD | 0x1000 |
| Catalan | Spain | ca-ES | 0x0403 |
| Catalan | France | ca-FR | 0x1000 |
| Catalan | Italy | ca-IT | 0x1000 |
| Chakma | Bangladesh | ccp-Cakm-BD | 0x1000 |
| Chakma | India | ccp-Cakm-IN | 0x1000 |
| Chechen | Russia | ce-RU | 0x1000 |
| Cebuan (Latin) | Philippines | ceb-Latn-PH | 0x1000 |
| Chiga | Uganda | cgg-UG | 0x1000 |
| Cherokee | United States | chr-Cher-US | 0x045C |
| Corsican | France | co-FR | 0x0483 |
| Czech | Czech Republic | cs-CZ | 0x0405 |
| Church Slavic | Russia | cu-RU | 0x1000 |
| Chuvash (Cyrillic) | Russia | cv-Cyrl-RU | 0x1000 |
| Welsh | United Kingdom | cy-GB | 0x0452 |
| Danish | Denmark | da-DK | 0x0406 |
| Danish | Greenland | da-GL | 0x1000 |
| Taita | Kenya | dav-KE | 0x1000 |
| German | Austria | de-AT | 0x0C07 |
| German | Belgium | de-BE | 0x1000 |
| German | Switzerland | de-CH | 0x0807 |
| German | Germany | de-DE | 0x0407 |
| German | Italy | de-IT | 0x1000 |
| German | Liechtenstein | de-LI | 0x1407 |
| German | Luxembourg | de-LU | 0x1007 |
| Zarma | Niger | dje-NE | 0x1000 |
| Lower Sorbian | Germany | dsb-DE | 0x082E |
| Duala | Cameroon | dua-CM | 0x1000 |
| Divehi | Maldives | dv-MV | 0x0465 |
| Jola-Fonyi | Senegal | dyo-SN | 0x1000 |
| Dzongkha | Bhutan | dz-BT | 0x0C51 |
| Embu | Kenya | ebu-KE | 0x1000 |
| Ewe | Ghana | ee-GH | 0x1000 |
| Ewe | Togo | ee-TG | 0x1000 |
| Greek | Cyprus | el-CY | 0x1000 |
| Greek | Greece | el-GR | 0x0408 |
| English | World | en-001 | 0x1000 |
| English | Caribbean | en-029 | 0x2409 |
| English | Europe | en-150 | 0x1000 |
| English | United Arab Emirates | en-AE | 0x4C09 |
| English | Antigua and Barbuda | en-AG | 0x1000 |
| English | Anguilla | en-AI | 0x1000 |
| English | American Samoa | en-AS | 0x1000 |
| English | Austria | en-AT | 0x1000 |
| English | Australia | en-AU | 0x0C09 |
| English | Barbados | en-BB | 0x1000 |
| English | Belgium | en-BE | 0x1000 |
| English | Burundi | en-BI | 0x1000 |
| English | Bermuda | en-BM | 0x1000 |
| English | Bahamas | en-BS | 0x1000 |
| English | Botswana | en-BW | 0x1000 |
| English | Belize | en-BZ | 0x2809 |
| English | Canada | en-CA | 0x1009 |
| English | Cocos [Keeling] Islands | en-CC | 0x1000 |
| English | Switzerland | en-CH | 0x1000 |
| English | Cook Islands | en-CK | 0x1000 |
| English | Cameroon | en-CM | 0x1000 |
| English | Christmas Island | en-CX | 0x1000 |
| English | Cyprus | en-CY | 0x1000 |
| English | Germany | en-DE | 0x1000 |
| English | Denmark | en-DK | 0x1000 |
| English | Dominica | en-DM | 0x1000 |
| English | Eritrea | en-ER | 0x1000 |
| English | Finland | en-FI | 0x1000 |
| English | Fiji | en-FJ | 0x1000 |
| English | Falkland Islands | en-FK | 0x1000 |
| English | Micronesia | en-FM | 0x1000 |
| English | United Kingdom | en-GB | 0x0809 |
| English | Grenada | en-GD | 0x1000 |
| English | Guernsey | en-GG | 0x1000 |
| English | Ghana | en-GH | 0x1000 |
| English | Gibraltar | en-GI | 0x1000 |
| English | Gambia | en-GM | 0x1000 |
| English | Guam | en-GU | 0x1000 |
| English | Guyana | en-GY | 0x1000 |
| English | Hong Kong | en-HK | 0x3C09 |
| English | Ireland | en-IE | 0x1809 |
| English | Israel | en-IL | 0x1000 |
| English | Isle of Man | en-IM | 0x1000 |
| English | India | en-IN | 0x4009 |
| English | British Indian Ocean Territory | en-IO | 0x1000 |
| English | Jersey | en-JE | 0x1000 |
| English | Jamaica | en-JM | 0x2009 |
| English | Kenya | en-KE | 0x1000 |
| English | Kiribati | en-KI | 0x1000 |
| English | Saint Kitts and Nevis | en-KN | 0x1000 |
| English | Cayman Islands | en-KY | 0x1000 |
| English | Saint Lucia | en-LC | 0x1000 |
| English | Liberia | en-LR | 0x1000 |
| English | Lesotho | en-LS | 0x1000 |
| English | Madagascar | en-MG | 0x1000 |
| English | Marshall Islands | en-MH | 0x1000 |
| English | Macao SAR | en-MO | 0x1000 |
| English | Northern Mariana Islands | en-MP | 0x1000 |
| English | Montserrat | en-MS | 0x1000 |
| English | Malta | en-MT | 0x1000 |
| English | Mauritius | en-MU | 0x1000 |
| English | Maldives | en-MV | 0x1000 |
| English | Malawi | en-MW | 0x1000 |
| English | Malaysia | en-MY | 0x4409 |
| English | Namibia | en-NA | 0x1000 |
| English | Norfolk Island | en-NF | 0x1000 |
| English | Nigeria | en-NG | 0x1000 |
| English | Netherlands | en-NL | 0x1000 |
| English | Nauru | en-NR | 0x1000 |
| English | Niue | en-NU | 0x1000 |
| English | New Zealand | en-NZ | 0x1409 |
| English | Papua New Guinea | en-PG | 0x1000 |
| English | Republic of the Philippines | en-PH | 0x3409 |
| English | Pakistan | en-PK | 0x1000 |
| English | Pitcairn Islands | en-PN | 0x1000 |
| English | Puerto Rico | en-PR | 0x1000 |
| English | Palau | en-PW | 0x1000 |
| English | Rwanda | en-RW | 0x1000 |
| English | Solomon Islands | en-SB | 0x1000 |
| English | Seychelles | en-SC | 0x1000 |
| English | Sudan | en-SD | 0x1000 |
| English | Sweden | en-SE | 0x1000 |
| English | Singapore | en-SG | 0x4809 |
| English | St Helena, Ascension, Tristan da Cunha | en-SH | 0x1000 |
| English | Slovenia | en-SI | 0x1000 |
| English | Sierra Leone | en-SL | 0x1000 |
| English | South Sudan | en-SS | 0x1000 |
| English | Sint Maarten | en-SX | 0x1000 |
| English | Swaziland | en-SZ | 0x1000 |
| English | Turks and Caicos Islands | en-TC | 0x1000 |
| English | Tokelau | en-TK | 0x1000 |
| English | Tonga | en-TO | 0x1000 |
| English | Trinidad and Tobago | en-TT | 0x2c09 |
| English | Tuvalu | en-TV | 0x1000 |
| English | Tanzania | en-TZ | 0x1000 |
| English | Uganda | en-UG | 0x1000 |
| English | US Minor Outlying Islands | en-UM | 0x1000 |
| English | United States | en-US | 0x0409 |
| English | Saint Vincent and the Grenadines | en-VC | 0x1000 |
| English | British Virgin Islands | en-VG | 0x1000 |
| English | US Virgin Islands | en-VI | 0x1000 |
| English | Vanuatu | en-VU | 0x1000 |
| English | Samoa | en-WS | 0x1000 |
| English | South Africa | en-ZA | 0x1C09 |
| English | Zambia | en-ZM | 0x1000 |
| English | Zimbabwe | en-ZW | 0x3009 |
| Esperanto | World | eo-001 | 0x1000 |
| Spanish | Latin America | es-419 | 0x580A |
| Spanish | Argentina | es-AR | 0x2C0A |
| Spanish | Bolivia | es-BO | 0x400A |
| Spanish | Brazil | es-BR | 0x1000 |
| Spanish | Belize | es-BZ | 0x1000 |
| Spanish | Chile | es-CL | 0x340A |
| Spanish | Colombia | es-CO | 0x240A |
| Spanish | Costa Rica | es-CR | 0x140A |
| Spanish | Cuba | es-CU | 0x5c0A |
| Spanish | Dominican Republic | es-DO | 0x1c0A |
| Spanish | Ecuador | es-EC | 0x300A |
| Spanish | Spain | es-ES | 0x0c0A |
| Spanish | Equatorial Guinea | es-GQ | 0x1000 |
| Spanish | Guatemala | es-GT | 0x100A |
| Spanish | Honduras | es-HN | 0x480A |
| Spanish | Mexico | es-MX | 0x080A |
| Spanish | Nicaragua | es-NI | 0x4C0A |
| Spanish | Panama | es-PA | 0x180A |
| Spanish | Peru | es-PE | 0x280A |
| Spanish | Philippines | es-PH | 0x1000 |
| Spanish | Puerto Rico | es-PR | 0x500A |
| Spanish | Paraguay | es-PY | 0x3C0A |
| Spanish | El Salvador | es-SV | 0x440A |
| Spanish | United States | es-US | 0x540A |
| Spanish | Uruguay | es-UY | 0x380A |
| Spanish | Bolivarian Republic of Venezuela | es-VE | 0x200A |
| Estonian | Estonia | et-EE | 0x0425 |
| Basque | Spain | eu-ES | 0x042D |
| Ewondo | Cameroon | ewo-CM | 0x1000 |
| Persian | Afghanistan | fa-AF | 0x1000 |
| Persian | Iran | fa-IR | 0x0429 |
| Fulah | Cameroon | ff-CM | 0x1000 |
| Fulah | Guinea | ff-GN | 0x1000 |
| Fulah (Latin) | Burkina Faso | ff-Latn-BF | 0x1000 |
| Fulah (Latin) | Cameroon | ff-Latn-CM | 0x1000 |
| Fulah (Latin) | Ghana | ff-Latn-GH | 0x1000 |
| Fulah (Latin) | Gambia | ff-Latn-GM | 0x1000 |
| Fulah (Latin) | Guinea | ff-Latn-GN | 0x1000 |
| Fulah (Latin) | Guinea-Bissau | ff-Latn-GW | 0x1000 |
| Fulah (Latin) | Liberia | ff-Latn-LR | 0x1000 |
| Fulah (Latin) | Mauritania | ff-Latn-MR | 0x1000 |
| Fulah (Latin) | Niger | ff-Latn-NE | 0x1000 |
| Fulah (Latin) | Nigeria | ff-Latn-NG | 0x0467 |
| Fulah (Latin) | Sierra Leone | ff-Latn-SL | 0x1000 |
| Fulah | Senegal | ff-Latn-SN | 0x0867 |
| Fulah | Mauritania | ff-MR | 0x1000 |
| Fulah | Nigeria | ff-NG | 0x0467 |
| Finnish | Finland | fi-FI | 0x040B |
| Filipino | Philippines | fil-PH | 0x0464 |
| Faroese | Denmark | fo-DK | 0x1000 |
| Faroese | Faroe Islands | fo-FO | 0x0438 |
| French | Caribbean | fr-029 | 0x1C0C |
| French | Belgium | fr-BE | 0x080C |
| French | Burkina Faso | fr-BF | 0x1000 |
| French | Burundi | fr-BI | 0x1000 |
| French | Benin | fr-BJ | 0x1000 |
| French | Saint Barthélemy | fr-BL | 0x1000 |
| French | Canada | fr-CA | 0x0c0C |
| French | Congo, DRC | fr-CD | 0x240C |
| French | Central African Republic | fr-CF | 0x1000 |
| French | Congo | fr-CG | 0x1000 |
| French | Switzerland | fr-CH | 0x100C |
| French | Côte d'Ivoire | fr-CI | 0x300C |
| French | Cameroon | fr-CM | 0x2c0C |
| French | Djibouti | fr-DJ | 0x1000 |
| French | Algeria | fr-DZ | 0x1000 |
| French | France | fr-FR | 0x040C |
| French | Gabon | fr-GA | 0x1000 |
| French | French Guiana | fr-GF | 0x1000 |
| French | Guinea | fr-GN | 0x1000 |
| French | Guadeloupe | fr-GP | 0x1000 |
| French | Equatorial Guinea | fr-GQ | 0x1000 |
| French | Haiti | fr-HT | 0x3c0C |
| French | Comoros | fr-KM | 0x1000 |
| French | Luxembourg | fr-LU | 0x140C |
| French | Morocco | fr-MA | 0x380C |
| French | Principality of Monaco | fr-MC | 0x180C |
| French | Saint Martin | fr-MF | 0x1000 |
| French | Madagascar | fr-MG | 0x1000 |
| French | Mali | fr-ML | 0x340C |
| French | Martinique | fr-MQ | 0x1000 |
| French | Mauritania | fr-MR | 0x1000 |
| French | Mauritius | fr-MU | 0x1000 |
| French | New Caledonia | fr-NC | 0x1000 |
| French | Niger | fr-NE | 0x1000 |
| French | French Polynesia | fr-PF | 0x1000 |
| French | Saint Pierre and Miquelon | fr-PM | 0x1000 |
| French | Reunion | fr-RE | 0x200C |
| French | Rwanda | fr-RW | 0x1000 |
| French | Seychelles | fr-SC | 0x1000 |
| French | Senegal | fr-SN | 0x280C |
| French | Syria | fr-SY | 0x1000 |
| French | Chad | fr-TD | 0x1000 |
| French | Togo | fr-TG | 0x1000 |
| French | Tunisia | fr-TN | 0x1000 |
| French | Vanuatu | fr-VU | 0x1000 |
| French | Wallis and Futuna | fr-WF | 0x1000 |
| French | Mayotte | fr-YT | 0x1000 |
| Friulian | Italy | fur-IT | 0x1000 |
| Frisian | Netherlands | fy-NL | 0x0462 |
| Irish | Ireland | ga-IE | 0x083C |
| Scottish Gaelic | United Kingdom | gd-GB | 0x0491 |
| Galician | Spain | gl-ES | 0x0456 |
| Guarani | Paraguay | gn-PY | 0x0474 |
| Alsatian | Switzerland | gsw-CH | 0x1000 |
| Alsatian | France | gsw-FR | 0x0484 |
| Alsatian | Liechtenstein | gsw-LI | 0x1000 |
| Gujarati | India | gu-IN | 0x0447 |
| Gusii | Kenya | guz-KE | 0x1000 |
| Manx | Isle of Man | gv-IM | 0x1000 |
| Hausa (Latin) | Ghana | ha-Latn-GH | 0x1000 |
| Hausa (Latin) | Niger | ha-Latn-NE | 0x1000 |
| Hausa (Latin) | Nigeria | ha-Latn-NG | 0x0468 |
| Hawaiian | United States | haw-US | 0x0475 |
| Hebrew | Israel | he-IL | 0x040D |
| Hindi | India | hi-IN | 0x0439 |
| Hindi (Latin) | India | hi-Latn-IN | 0x1000 |
| Croatian (Latin) | Bosnia and Herzegovina | hr-BA | 0x101A |
| Croatian | Croatia | hr-HR | 0x041A |
| Upper Sorbian | Germany | hsb-DE | 0x042E |
| Hungarian | Hungary | hu-HU | 0x040E |
| Armenian | Armenia | hy-AM | 0x042B |
| Interlingua | World | ia-001 | 0x1000 |
| Interlingua | France | ia-FR | 0x1000 |
| Indonesian | Indonesia | id-ID | 0x0421 |
| Igbo | Nigeria | ig-NG | 0x0470 |
| Yi | People's Republic of China | ii-CN | 0x0478 |
| Icelandic | Iceland | is-IS | 0x040F |
| Italian | Switzerland | it-CH | 0x0810 |
| Italian | Italy | it-IT | 0x0410 |
| Italian | San Marino | it-SM | 0x1000 |
| Italian | Vatican City | it-VA | 0x1000 |
| Inuktitut (Syllabics) | Canada | iu-Cans-CA | 0x045d |
| Inuktitut (Latin) | Canada | iu-Latn-CA | 0x085D |
| Japanese | Japan | ja-JP | 0x0411 |
| Ngomba | Cameroon | jgo-CM | 0x1000 |
| Machame | Tanzania | jmc-TZ | 0x1000 |
| Javanese | Latin, Indonesia | jv-Latn-ID | 0x1000 |
| Georgian | Georgia | ka-GE | 0x0437 |
| Kabyle | Algeria | kab-DZ | 0x1000 |
| Kamba | Kenya | kam-KE | 0x1000 |
| Makonde | Tanzania | kde-TZ | 0x1000 |
| Kabuverdianu | Cabo Verde | kea-CV | 0x1000 |
| Kaingang (Latin) | Brazil | kgp-Latn-BR | 0x1000 |
| Koyra Chiini | Mali | khq-ML | 0x1000 |
| Kikuyu | Kenya | ki-KE | 0x1000 |
| Kazakh | Kazakhstan | kk-KZ | 0x043F |
| Kako | Cameroon | kkj-CM | 0x1000 |
| Greenlandic | Greenland | kl-GL | 0x046F |
| Kalenjin | Kenya | kln-KE | 0x1000 |
| Khmer | Cambodia | km-KH | 0x0453 |
| Kannada | India | kn-IN | 0x044B |
| Korean | North Korea | ko-KP | 0x1000 |
| Korean | Korea | ko-KR | 0x0412 |
| Konkani | India | kok-IN | 0x0457 |
| Kanuri (Latin) | Nigeria | kr-Latn-NG | 0x0471 |
| Kashmiri | Perso-Arabic | ks-Arab-IN | 0x1000 |
| Kashmiri (Devanagari) | India | ks-Deva-IN | 0x0860 |
| Shambala | Tanzania | ksb-TZ | 0x1000 |
| Bafia | Cameroon | ksf-CM | 0x1000 |
| Ripuarian | Germany | ksh-DE | 0x1000 |
| Central Kurdish | Iraq | ku-Arab-IQ | 0x0492 |
| Kurdish | Perso-Arabic, Iran | ku-Arab-IR | 0x1000 |
| Cornish | United Kingdom | kw-GB | 0x1000 |
| Kyrgyz | Kyrgyzstan | ky-KG | 0x0440 |
| Latin | Vatican City | la-VA | 0x0476 |
| Langi | Tanzania | lag-TZ | 0x1000 |
| Luxembourgish | Luxembourg | lb-LU | 0x046E |
| Ganda | Uganda | lg-UG | 0x1000 |
| Lakota | United States | lkt-US | 0x1000 |
| Lingala | Angola | ln-AO | 0x1000 |
| Lingala | Congo DRC | ln-CD | 0x1000 |
| Lingala | Central African Republic | ln-CF | 0x1000 |
| Lingala | Congo | ln-CG | 0x1000 |
| Lao | Lao P.D.R. | lo-LA | 0x0454 |
| Northern Luri | Iraq | lrc-IQ | 0x1000 |
| Northern Luri | Iran | lrc-IR | 0x1000 |
| Lithuanian | Lithuania | lt-LT | 0x0427 |
| Luba-Katanga | Congo DRC | lu-CD | 0x1000 |
| Luo | Kenya | luo-KE | 0x1000 |
| Luyia | Kenya | luy-KE | 0x1000 |
| Latvian | Latvia | lv-LV | 0x0426 |
| Masai | Kenya | mas-KE | 0x1000 |
| Masai | Tanzania | mas-TZ | 0x1000 |
| Meru | Kenya | mer-KE | 0x1000 |
| Morisyen | Mauritius | mfe-MU | 0x1000 |
| Malagasy | Madagascar | mg-MG | 0x1000 |
| Makhuwa-Meetto | Mozambique | mgh-MZ | 0x1000 |
| Meta' | Cameroon | mgo-CM | 0x1000 |
| Maori | New Zealand | mi-NZ | 0x0481 |
| Macedonian | North Macedonia | mk-MK | 0x042F |
| Malayalam | India | ml-IN | 0x044C |
| Mongolian (Cyrillic) | Mongolia | mn-MN | 0x0450 |
| Mongolian (Traditional Mongolian) | People's Republic of China | mn-Mong-CN | 0x0850 |
| Mongolian (Traditional Mongolian) | Mongolia | mn-Mong-MN | 0x0C50 |
| Mohawk | Canada | moh-CA | 0x047C |
| Marathi | India | mr-IN | 0x044E |
| Malay | Brunei Darussalam | ms-BN | 0x083E |
| Malay | Malaysia | ms-MY | 0x043E |
| Maltese | Malta | mt-MT | 0x043A |
| Mundang | Cameroon | mua-CM | 0x1000 |
| Burmese | Myanmar | my-MM | 0x0455 |
| Mazanderani | Iran | mzn-IR | 0x1000 |
| Nama | Namibia | naq-NA | 0x1000 |
| Norwegian (Bokmal) | Norway | nb-NO | 0x0414 |
| Norwegian Bokmål | Svalbard and Jan Mayen | nb-SJ | 0x1000 |
| North Ndebele | Zimbabwe | nd-ZW | 0x1000 |
| Low German | Germany | nds-DE | 0x1000 |
| Low German | Netherlands | nds-NL | 0x1000 |
| Nepali | India | ne-IN | 0x0861 |
| Nepali | Nepal | ne-NP | 0x0461 |
| Dutch | Aruba | nl-AW | 0x1000 |
| Dutch | Belgium | nl-BE | 0x0813 |
| Dutch | Bonaire, Sint Eustatius and Saba | nl-BQ | 0x1000 |
| Dutch | Curaçao | nl-CW | 0x1000 |
| Dutch | Netherlands | nl-NL | 0x0413 |
| Dutch | Suriname | nl-SR | 0x1000 |
| Dutch | Sint Maarten | nl-SX | 0x1000 |
| Kwasio | Cameroon | nmg-CM | 0x1000 |
| Norwegian (Nynorsk) | Norway | nn-NO | 0x0814 |
| Ngiemboon | Cameroon | nnh-CM | 0x1000 |
| N'ko | Guinea | nqo-GN | 0x1000 |
| South Ndebele | South Africa | nr-ZA | 0x1000 |
| Sesotho sa Leboa | South Africa | nso-ZA | 0x046C |
| Nuer | Sudan | nus-SD | 0x1000 |
| Nuer | South Sudan | nus-SS | 0x1000 |
| Nyankole | Uganda | nyn-UG | 0x1000 |
| Occitan | Spain | oc-ES | 0x1000 |
| Occitan | France | oc-FR | 0x0482 |
| Oromo | Ethiopia | om-ET | 0x0472 |
| Oromo | Kenya | om-KE | 0x1000 |
| Odia | India | or-IN | 0x0448 |
| Ossetian | Cyrillic, Georgia | os-GE | 0x1000 |
| Ossetian | Cyrillic, Russia | os-RU | 0x1000 |
| Punjabi | Islamic Republic of Pakistan | pa-Arab-PK | 0x0846 |
| Punjabi | India | pa-IN | 0x0446 |
| Polish | Poland | pl-PL | 0x0415 |
| Prussian |  | prg-001 | 0x1000 |
| Dari | Afghanistan | prs-AF | 0x048C |
| Pashto | Afghanistan | ps-AF | 0x0463 |
| Pashto | Pakistan | ps-PK | 0x1000 |
| Portuguese | Angola | pt-AO | 0x1000 |
| Portuguese | Brazil | pt-BR | 0x0416 |
| Portuguese | Switzerland | pt-CH | 0x1000 |
| Portuguese | Cabo Verde | pt-CV | 0x1000 |
| Portuguese | Equatorial Guinea | pt-GQ | 0x1000 |
| Portuguese | Guinea-Bissau | pt-GW | 0x1000 |
| Portuguese | Luxembourg | pt-LU | 0x1000 |
| Portuguese | Macao SAR | pt-MO | 0x1000 |
| Portuguese | Mozambique | pt-MZ | 0x1000 |
| Portuguese | Portugal | pt-PT | 0x0816 |
| Portuguese | São Tomé and Príncipe | pt-ST | 0x1000 |
| Portuguese | Timor-Leste | pt-TL | 0x1000 |
| K'iche | Guatemala | quc-Latn-GT | 0x0486 |
| Quechua | Bolivia | quz-BO | 0x046B |
| Quechua | Ecuador | quz-EC | 0x086B |
| Quechua | Peru | quz-PE | 0x0C6B |
| Rajasthani (Devanagari) | India | raj-Deva-IN | 0x1000 |
| Romansh | Switzerland | rm-CH | 0x0417 |
| Rundi | Burundi | rn-BI | 0x1000 |
| Romanian | Moldova | ro-MD | 0x0818 |
| Romanian | Romania | ro-RO | 0x0418 |
| Rombo | Tanzania | rof-TZ | 0x1000 |
| Russian | Belarus | ru-BY | 0x1000 |
| Russian | Kyrgyzstan | ru-KG | 0x1000 |
| Russian | Kazakhstan | ru-KZ | 0x1000 |
| Russian | Moldova | ru-MD | 0x0819 |
| Russian | Russia | ru-RU | 0x0419 |
| Russian | Ukraine | ru-UA | 0x1000 |
| Kinyarwanda | Rwanda | rw-RW | 0x0487 |
| Rwa | Tanzania | rwk-TZ | 0x1000 |
| Sanskrit | India | sa-IN | 0x044F |
| Sakha | Russia | sah-RU | 0x0485 |
| Samburu | Kenya | saq-KE | 0x1000 |
| Sangu | Tanzania | sbp-TZ | 0x1000 |
| Sardinian (Latin) | Italy | sc-Latn-IT | 0x1000 |
| Sindhi | Islamic Republic of Pakistan | sd-Arab-PK | 0x0859 |
| Sami (Northern) | Finland | se-FI | 0x0C3B |
| Sami (Northern) | Norway | se-NO | 0x043B |
| Sami (Northern) | Sweden | se-SE | 0x083B |
| Sena | Mozambique | seh-MZ | 0x1000 |
| Koyraboro Senni | Mali | ses-ML | 0x1000 |
| Sango | Central African Republic | sg-CF | 0x1000 |
| Tachelhit (Latin) | Morocco | shi-Latn-MA | 0x1000 |
| Tachelhit | Tifinagh, Morocco | shi-Tfng-MA | 0x1000 |
| Sinhala | Sri Lanka | si-LK | 0x045B |
| Slovak | Slovakia | sk-SK | 0x041B |
| Slovenian | Slovenia | sl-SI | 0x0424 |
| Sami (Southern) | Norway | sma-NO | 0x183B |
| Sami (Southern) | Sweden | sma-SE | 0x1C3B |
| Sami (Lule) | Norway | smj-NO | 0x103B |
| Sami (Lule) | Sweden | smj-SE | 0x143B |
| Sami (Inari) | Finland | smn-FI | 0x243B |
| Sami (Skolt) | Finland | sms-FI | 0x203B |
| Shona | Zimbabwe | sn-Latn-ZW | 0x1000 |
| Somali | Djibouti | so-DJ | 0x1000 |
| Somali | Ethiopia | so-ET | 0x1000 |
| Somali | Kenya | so-KE | 0x1000 |
| Somali | Somalia | so-SO | 0x0477 |
| Albanian | Albania | sq-AL | 0x041C |
| Albanian | North Macedonia | sq-MK | 0x1000 |
| Serbian (Cyrillic) | Bosnia and Herzegovina | sr-Cyrl-BA | 0x1C1A |
| Serbian (Cyrillic) | Serbia and Montenegro (Former) | sr-Cyrl-CS | 0x0C1A |
| Serbian (Cyrillic) | Montenegro | sr-Cyrl-ME | 0x301A |
| Serbian (Cyrillic) | Serbia | sr-Cyrl-RS | 0x281A |
| Serbian (Latin) | Bosnia and Herzegovina | sr-Latn-BA | 0x181A |
| Serbian (Latin) | Serbia and Montenegro (Former) | sr-Latn-CS | 0x081A |
| Serbian (Latin) | Montenegro | sr-Latn-ME | 0x2c1A |
| Serbian (Latin) | Serbia | sr-Latn-RS | 0x241A |
| Swati | Swaziland | ss-SZ | 0x1000 |
| Swati | South Africa | ss-ZA | 0x1000 |
| Saho | Eritrea | ssy-ER | 0x1000 |
| Southern Sotho | Lesotho | st-LS | 0x1000 |
| Sotho | South Africa | st-ZA | 0x0430 |
| Swedish | Åland Islands | sv-AX | 0x1000 |
| Swedish | Finland | sv-FI | 0x081D |
| Swedish | Sweden | sv-SE | 0x041D |
| Kiswahili | Kenya | sw-KE | 0x0441 |
| Kiswahili | Tanzania | sw-TZ | 0x1000 |
| Kiswahili | Uganda | sw-UG | 0x1000 |
| Congo Swahili | Congo DRC | swc-CD | 0x1000 |
| Syriac | Syria | syr-SY | 0x045A |
| Tamil | India | ta-IN | 0x0449 |
| Tamil | Sri Lanka | ta-LK | 0x0849 |
| Tamil | Malaysia | ta-MY | 0x1000 |
| Tamil | Singapore | ta-SG | 0x1000 |
| Telugu | India | te-IN | 0x044A |
| Teso | Kenya | teo-KE | 0x1000 |
| Teso | Uganda | teo-UG | 0x1000 |
| Tajik (Cyrillic) | Tajikistan | tg-Cyrl-TJ | 0x0428 |
| Thai | Thailand | th-TH | 0x041E |
| Tigrinya | Eritrea | ti-ER | 0x0873 |
| Tigrinya | Ethiopia | ti-ET | 0x0473 |
| Tigre | Eritrea | tig-ER | 0x1000 |
| Turkmen | Turkmenistan | tk-TM | 0x0442 |
| Setswana | Botswana | tn-BW | 0x0832 |
| Setswana | South Africa | tn-ZA | 0x0432 |
| Tongan | Tonga | to-TO | 0x1000 |
| Turkish | Cyprus | tr-CY | 0x1000 |
| Turkish | Turkey | tr-TR | 0x041F |
| Tsonga | South Africa | ts-ZA | 0x0431 |
| Tatar | Russia | tt-RU | 0x0444 |
| Tasawaq | Niger | twq-NE | 0x1000 |
| Central Atlas Tamazight (Arabic) | Morocco | tzm-Arab-MA | 0x045F |
| Tamazight (Latin) | Algeria | tzm-Latn-DZ | 0x085F |
| Central Atlas Tamazight (Latin) | Morocco | tzm-Latn-MA | 0x1000 |
| Uyghur | People's Republic of China | ug-CN | 0x0480 |
| Ukrainian | Ukraine | uk-UA | 0x0422 |
| Urdu | India | ur-IN | 0x0820 |
| Urdu | Islamic Republic of Pakistan | ur-PK | 0x0420 |
| Uzbek | Perso-Arabic, Afghanistan | uz-Arab-AF | 0x1000 |
| Uzbek (Cyrillic) | Uzbekistan | uz-Cyrl-UZ | 0x0843 |
| Uzbek (Latin) | Uzbekistan | uz-Latn-UZ | 0x0443 |
| Vai (Latin) | Liberia | vai-Latn-LR | 0x1000 |
| Vai | Liberia | vai-Vaii-LR | 0x1000 |
| Venda | South Africa | ve-ZA | 0x0433 |
| Vietnamese | Vietnam | vi-VN | 0x042A |
| Volapük | World | vo-001 | 0x1000 |
| Vunjo | Tanzania | vun-TZ | 0x1000 |
| Walser | Switzerland | wae-CH | 0x1000 |
| Wolaytta | Ethiopia | wal-ET | 0x1000 |
| Wolof | Senegal | wo-SN | 0x0488 |
| Xhosa | South Africa | xh-ZA | 0x0434 |
| Soga | Uganda | xog-UG | 0x1000 |
| Yangben | Cameroon | yav-CM | 0x1000 |
| Yiddish | World | yi-001 | 0x043D |
| Yoruba | Benin | yo-BJ | 0x1000 |
| Yoruba | Nigeria | yo-NG | 0x046A |
| Nheengatu (Latin) | Brazil | yrl-Latn-BR | 0x1000 |
| Nheengatu (Latin) | Colombia | yrl-Latn-CO | 0x1000 |
| Nheengatu (Latin) | Venezuela | yrl-Latn-VE | 0x1000 |
| Standard Moroccan Tamazight | Morocco | zgh-Tfng-MA | 0x1000 |
| Chinese (Simplified) | People's Republic of China | zh-CN | 0x0804 |
| Chinese (Traditional) | Hong Kong S.A.R. | zh-HK | 0x0C04 |
| Chinese (Traditional) | Macao S.A.R. | zh-MO | 0x1404 |
| Chinese (Simplified) | Singapore | zh-SG | 0x1004 |
| Chinese (Traditional) | Taiwan | zh-TW | 0x0404 |
| Zulu | South Africa | zu-ZA | 0x0435 |
