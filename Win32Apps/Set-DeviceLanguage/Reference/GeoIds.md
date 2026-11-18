# 📍 GeoIds

All country and region values you can use for `-GeoId`, taken from the official Microsoft table of geographical locations.

Source: [Table of Geographical Locations](https://learn.microsoft.com/windows/win32/intl/table-of-geographical-locations) (Microsoft Learn)  
Retrieved: 2026-11-18  
Back to the [README](../README.md)

> The source table does not list ISO country codes. To get the GeoId for an ISO code, use the check below.

## Check on a device

```powershell
[System.Globalization.RegionInfo]::new("AT").GeoId
```

Replace `AT` with the two-letter ISO country code.

## Geographical locations

300 locations, sorted by name.

| Country/Region | GeoId | Official name |
|---|---|---|
| Afghanistan | 3 | Islamic Republic of Afghanistan |
| Africa | 742 |  |
| Åland Islands | 10028789 | Åland Islands |
| Albania | 6 | Republic of Albania |
| Algeria | 4 | Democratic and Popular Republic of Algeria |
| American Samoa | 10 | Territory of American Samoa |
| Americas | 10026358 |  |
| Andorra | 8 | Principality of Andorra |
| Angola | 9 | Republic of Angola |
| Anguilla | 300 | Anguilla |
| Antarctica | 301 | Antarctica |
| Antigua and Barbuda | 2 | Antigua and Barbuda |
| Argentina | 11 | Argentine Republic |
| Armenia | 7 | Republic of Armenia |
| Aruba | 302 | Aruba |
| Ascension Island | 303 |  |
| Ashmore and Cartier Islands | 304 | Territory of Ashmore and Cartier Islands |
| Asia | 2129 |  |
| Australia | 12 | Commonwealth of Australia |
| Australia and New Zealand | 10210825 |  |
| Austria | 14 | Republic of Austria |
| Azerbaijan | 5 | Republic of Azerbaijan |
| Bahamas, The | 22 | Commonwealth of The Bahamas |
| Bahrain | 17 | Kingdom of Bahrain |
| Baker Island | 305 |  |
| Bangladesh | 23 | People's Republic of Bangladesh |
| Barbados | 18 | Barbados |
| Belarus | 29 | Republic of Belarus |
| Belgium | 21 | Kingdom of Belgium |
| Belize | 24 | Belize |
| Benin | 28 | Republic of Benin |
| Bermuda | 20 | Bermuda |
| Bhutan | 34 | Kingdom of Bhutan |
| Bolivia | 26 | Plurinational State of Bolivia" |
| Bonaire, Sint Eustatius and Saba | 161832258 |  |
| Bosnia and Herzegovina | 25 | Bosnia and Herzegovina |
| Botswana | 19 | Republic of Botswana |
| Bouvet Island | 306 |  |
| Brazil | 32 | Federative Republic of Brazil |
| British Indian Ocean Territory | 114 | British Indian Ocean Territory |
| British Virgin Islands | 351 | British Virgin Islands |
| Brunei | 37 | Negara Brunei Darussalam |
| Bulgaria | 35 | Republic of Bulgaria |
| Burkina Faso | 245 | Burkina Faso |
| Burundi | 38 | Republic of Burundi |
| Cabo Verde | 57 | Republic of Cabo Verde |
| Cambodia | 40 | Kingdom of Cambodia |
| Cameroon | 49 | Republic of Cameroon |
| Canada | 39 | Canada |
| Caribbean | 10039880 |  |
| Cayman Islands | 307 | Cayman Islands |
| Central African Republic | 55 | Central African Republic |
| Central America | 27082 |  |
| Central Asia | 47590 |  |
| Chad | 41 | Republic of Chad |
| Channel Islands | 308 |  |
| Chile | 46 | Republic of Chile |
| China | 45 | People's Republic of China |
| Christmas Island | 309 | Territory of Christmas Island |
| Clipperton Island | 310 |  |
| Cocos (Keeling) Islands | 311 | Territory of Cocos (Keeling) Islands |
| Colombia | 51 | Republic of Colombia |
| Comoros | 50 | Union of Comoros |
| Congo | 43 | Republic of the Congo |
| Congo (DRC) | 44 | Democratic Republic of the Congo |
| Cook Islands | 312 |  |
| Coral Sea Islands | 313 | Coral Sea Islands Territory |
| Costa Rica | 54 | Republic of Costa Rica |
| Côte d'Ivoire | 119 | Republic of Côte d'Ivoire |
| Croatia | 108 | Republic of Croatia |
| Cuba | 56 | Republic of Cuba |
| Curaçao | 273 |  |
| Cyprus | 59 | Republic of Cyprus |
| Czech Republic | 75 | Czech Republic |
| Denmark | 61 | Kingdom of Denmark |
| Diego Garcia | 314 |  |
| Djibouti | 62 | Republic of Djibouti |
| Dominica | 63 | Commonwealth of Dominica |
| Dominican Republic | 65 | Dominican Republic |
| Eastern Africa | 47603 |  |
| Eastern Asia | 47600 |  |
| Eastern Europe | 47609 |  |
| Ecuador | 66 | Republic of Ecuador |
| Egypt | 67 | Arab Republic of Egypt |
| El Salvador | 72 | Republic of El Salvador |
| Equatorial Guinea | 69 | Republic of Equatorial Guinea |
| Eritrea | 71 | State of Eritrea |
| Estonia | 70 | Republic of Estonia |
| Ethiopia | 73 | Federal Democratic Republic of Ethiopia |
| Europe | 10541 |  |
| Falkland Islands | 315 | Falkland Islands |
| Faroe Islands | 81 | Faroe Islands |
| Fiji | 78 | The Republic of Fiji |
| Finland | 77 | Republic of Finland |
| France | 84 | French Republic |
| French Guiana | 317 | Department of Guiana |
| French Polynesia | 318 | Territory of French Polynesia |
| French Southern Territories | 319 | Territory of the French Southern and Antarctic Lands |
| Gabon | 87 | Gabonese Republic |
| Gambia | 86 | Republic of The Gambia |
| Georgia | 88 | Georgia |
| Germany | 94 | Federal Republic of Germany |
| Ghana | 89 | Republic of Ghana |
| Gibraltar | 90 | Gibraltar |
| Greece | 98 | Hellenic Republic |
| Greenland | 93 | Greenland |
| Grenada | 91 | Grenada |
| Guadeloupe | 321 | Department of Guadeloupe |
| Guam | 322 | Territory of Guam |
| Guantanamo Bay | 323 |  |
| Guatemala | 99 | Republic of Guatemala |
| Guernsey | 324 | Bailiwick of Guernsey |
| Guinea | 100 | Republic of Guinea |
| Guinea-Bissau | 196 | Republic of Guinea-Bissau |
| Guyana | 101 | Cooperative Republic of Guyana |
| Haiti | 103 | Republic of Haiti |
| Heard Island and McDonald Islands | 325 | Territory of Heard Island and McDonald Islands |
| Honduras | 106 | Republic of Honduras |
| Hong Kong SAR | 104 | Hong Kong Special Administrative Region |
| Howland Island | 326 |  |
| Hungary | 109 | Republic of Hungary |
| Iceland | 110 | Republic of Iceland |
| India | 113 | Republic of India |
| Indonesia | 111 | Republic of Indonesia |
| Iran | 116 | Islamic Republic of Iran |
| Iraq | 121 | Republic of Iraq |
| Ireland | 68 | Ireland |
| Isle of Man | 15126 | Isle of Man |
| Israel | 117 | State of Israel |
| Italy | 118 | Italian Republic |
| Jamaica | 124 | Jamaica |
| Jan Mayen | 125 | Jan Mayen |
| Japan | 122 | Japan |
| Jarvis Island | 327 |  |
| Jersey | 328 | Bailiwick of Jersey |
| Johnston Atoll | 127 |  |
| Jordan | 126 | Hashemite Kingdom of Jordan |
| Kazakhstan | 137 | Republic of Kazakhstan |
| Kenya | 129 | Republic of Kenya |
| Kingman Reef | 329 |  |
| Kiribati | 133 | Republic of Kiribati |
| Korea | 134 | Republic of Korea |
| Kosovo | 9914689 | Kosovo |
| Kuwait | 136 | State of Kuwait |
| Kyrgyzstan | 130 | Kyrgyz Republic |
| Laos | 138 | Lao People's Democratic Republic |
| Latin America and the Caribbean | 161832257 |  |
| Latvia | 140 | Republic of Latvia |
| Lebanon | 139 | Republic of Lebanon |
| Lesotho | 146 | Kingdom of Lesotho |
| Liberia | 142 | Republic of Liberia |
| Libya | 148 | Libya |
| Liechtenstein | 145 | Principality of Liechtenstein |
| Lithuania | 141 | Republic of Lithuania |
| Luxembourg | 147 | Grand Duchy of Luxembourg |
| Macao SAR | 151 | Macao Special Administrative Region |
| Madagascar | 149 | Republic of Madagascar |
| Malawi | 156 | Republic of Malawi |
| Malaysia | 167 | Federation of Malaysia |
| Maldives | 165 | Republic of Maldives |
| Mali | 157 | Republic of Mali |
| Malta | 163 | Republic of Malta |
| Marshall Islands | 199 | Republic of the Marshall Islands |
| Martinique | 330 | Department of Martinique |
| Mauritania | 162 | Islamic Republic of Mauritania |
| Mauritius | 160 | Republic of Mauritius |
| Mayotte | 331 | Territorial Collectivity of Mayotte |
| Melanesia | 20900 |  |
| Mexico | 166 | United Mexican States |
| Micronesia | 80 | Federated States of Micronesia |
| Micronesia | 21206 | Federated States of Micronesia |
| Middle Africa | 42484 |  |
| Middle East | 47611 | Western Asia |
| Midway Islands | 21242 |  |
| Moldova | 152 | Republic of Moldova |
| Monaco | 158 | Principality of Monaco |
| Mongolia | 154 | Mongolia |
| Montenegro | 270 | Montenegro |
| Montserrat | 332 | Montserrat |
| Morocco | 159 | Kingdom of Morocco |
| Mozambique | 168 | Republic of Mozambique |
| Myanmar | 27 | Republic of the Union of Myanmar |
| Namibia | 254 | Republic of Namibia |
| Nauru | 180 | Republic of Nauru |
| Nepal | 178 | Federal Democratic Republic of Nepal |
| Netherlands | 176 | Kingdom of the Netherlands |
| Netherlands Antilles (Former) | 333 |  |
| New Caledonia | 334 | Territory of New Caledonia and Dependencies |
| New Zealand | 183 | New Zealand |
| Nicaragua | 182 | Republic of Nicaragua |
| Niger | 173 | Republic of Niger |
| Nigeria | 175 | Federal Republic of Nigeria |
| Niue | 335 |  |
| Norfolk Island | 336 | Territory of Norfolk Island |
| North Korea | 131 | Democratic People's Republic of Korea |
| North Macedonia | 19618 | The Former Yugoslav Republic of North Macedonia |
| Northern Africa | 42487 |  |
| Northern America | 23581 |  |
| Northern Europe | 10039882 |  |
| Northern Mariana Islands | 337 | Commonwealth of the Northern Mariana Islands |
| Norway | 177 | Kingdom of Norway |
| Oceania | 27114 |  |
| Oman | 164 | Sultanate of Oman |
| Pakistan | 190 | Islamic Republic of Pakistan |
| Palau | 195 | Republic of Palau |
| Palestinian Authority | 184 | Palestinian National Authority |
| Palmyra Atoll | 338 |  |
| Panama | 192 | Republic of Panama |
| Papua New Guinea | 194 | Independent State of Papua New Guinea |
| Paraguay | 185 | Republic of Paraguay |
| Peru | 187 | Republic of Peru |
| Philippines | 201 | Republic of the Philippines |
| Pitcairn Islands | 339 | Pitcairn, Henderson, Ducie, and Oeno Islands |
| Poland | 191 | Republic of Poland |
| Polynesia | 26286 |  |
| Portugal | 193 | Portuguese Republic |
| Puerto Rico | 202 | Commonwealth of Puerto Rico |
| Qatar | 197 | State of Qatar |
| Réunion | 198 | Department of Réunion |
| Romania | 200 | Romania |
| Rota Island | 340 |  |
| Russia | 203 | Russian Federation |
| Rwanda | 204 | Republic of Rwanda |
| Saint Barthélemy | 161832015 | Overseas Collectivity of Saint Barthélemy |
| Saint Kitts and Nevis | 207 | Federation of Saint Kitts and Nevis |
| Saint Lucia | 218 | Saint Lucia |
| Saint Martin | 31706 | Overseas Collectivity of Saint Martin |
| Saint Pierre and Miquelon | 206 | Territorial Collectivity of Saint Pierre and Miquelon |
| Saint Vincent and the Grenadines | 248 | Saint Vincent and the Grenadines |
| Saipan | 341 |  |
| Samoa | 259 | Independent State of Samoa |
| San Marino | 214 | Republic of San Marino |
| São Tomé and Príncipe | 233 | Democratic Republic of São Tomé and Príncipe |
| Saudi Arabia | 205 | Kingdom of Saudi Arabia |
| Senegal | 210 | Republic of Senegal |
| Serbia | 271 | Serbia |
| Serbia and Montenegro (Former) | 269 | Serbia |
| Seychelles | 208 | Republic of Seychelles |
| Sierra Leone | 213 | Republic of Sierra Leone |
| Singapore | 215 | Republic of Singapore |
| Sint Maarten | 30967 | Country of Sint Maarten |
| Slovakia | 143 | Slovak Republic |
| Slovenia | 212 | Republic of Slovenia |
| Solomon Islands | 30 | Solomon Islands |
| Somalia | 216 | Federal Republic of Somalia |
| South Africa | 209 | Republic of South Africa |
| South America | 31396 |  |
| South Georgia and the South Sandwich Islands | 342 | South Georgia and the South Sandwich Islands |
| South Sudan | 276 | The Republic of South Sudan |
| South-Eastern Asia | 47599 |  |
| Southern Africa | 10039883 |  |
| Southern Asia | 47614 |  |
| Southern Europe | 47610 |  |
| Spain | 217 | Kingdom of Spain |
| Sri Lanka | 42 | Democratic Socialist Republic of Sri Lanka |
| St Helena, Ascension and Tristan da Cunha | 343 | Saint Helena, Ascension, and Tristan da Cunha |
| Sudan | 219 | Republic of the Sudan |
| Suriname | 181 | Republic of Suriname |
| Svalbard | 220 | Svalbard |
| Swaziland | 260 | Kingdom of Swaziland |
| Sweden | 221 | Kingdom of Sweden |
| Switzerland | 223 | Swiss Confederation |
| Syria | 222 | Syrian Arab Republic |
| Taiwan | 237 | Taiwan |
| Tajikistan | 228 | Republic of Tajikistan |
| Tanzania | 239 | United Republic of Tanzania |
| Thailand | 227 | Kingdom of Thailand |
| Timor-Leste | 7299303 | Democratic Republic of Timor-Leste |
| Tinian Island | 346 |  |
| Togo | 232 | Togolese Republic |
| Tokelau | 347 | Tokelau |
| Tonga | 231 | Kingdom of Tonga |
| Trinidad and Tobago | 225 | Republic of Trinidad and Tobago |
| Tristan da Cunha | 348 |  |
| Tunisia | 234 | Tunisian Republic |
| Türkiye | 235 | Republic of Türkiye |
| Turkmenistan | 238 | Republic of Turkmenistan |
| Turks and Caicos Islands | 349 | Turks and Caicos Islands |
| Tuvalu | 236 | Tuvalu |
| U.S. Minor Outlying Islands | 161832256 | United States Minor Outlying Islands |
| U.S. Virgin Islands | 252 | Virgin Islands of the United States |
| Uganda | 240 | Republic of Uganda |
| Ukraine | 241 | Ukraine |
| United Arab Emirates | 224 | United Arab Emirates |
| United Kingdom | 242 | United Kingdom of Great Britain and Northern Ireland |
| United States | 244 | United States of America |
| Uruguay | 246 | Oriental Republic of Uruguay |
| Uzbekistan | 247 | Republic of Uzbekistan |
| Vanuatu | 174 | Republic of Vanuatu |
| Vatican City | 253 | State of Vatican City |
| Venezuela | 249 | Bolivarian Republic of Venezuela |
| Vietnam | 251 | Socialist Republic of Vietnam |
| Wake Island | 258 |  |
| Wallis and Futuna | 352 | Territory of the Wallis and Futuna Islands |
| Western Africa | 42483 |  |
| Western Europe | 10210824 |  |
| World | 39070 |  |
| Yemen | 261 | Republic of Yemen |
| Zambia | 263 | Republic of Zambia |
| Zimbabwe | 264 | Republic of Zimbabwe |
