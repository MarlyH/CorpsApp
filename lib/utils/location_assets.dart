/// Map each exact locationName (from EventSummary.locationName)
/// to its corresponding asset path.
const Map<String, String> locationAssetMap = {
  'Ashburton'    : 'assets/location_assets/ASH_CORPS_FINAL.PNG',
  'Blenheim'     : 'assets/location_assets/BLEN_CORPS_FINAL.PNG',
  'Christchurch' : 'assets/location_assets/CHCH_CORPS_FINAL.png',
  'Balclutha'       : 'assets/location_assets/CLUTHA_CORPS_FINAL.PNG',
  'Cromwell'     : 'assets/location_assets/CROM_CORPS.png',
  'Dunedin'      : 'assets/location_assets/DUNE_CORPS_FINAL.PNG',
  'West Coast'   : 'assets/location_assets/FINAL_WEST_CORPS_LOGO.PNG',
  'Gore'         : 'assets/location_assets/GORE_CORPS_FINAL.PNG',
  'Hokitika'     : 'assets/location_assets/HOKITIKA_CORPS_FINAL.png',
  'Invercargill' : 'assets/location_assets/INVA_CORPS_FINAL.png',
  'Kaikoura'     : 'assets/location_assets/KAIKOURA_CORPS_FINAL.png',
  'Milton'       : 'assets/location_assets/MLTN_CORPS.png',
  'Nelson'       : 'assets/location_assets/NLSN_CORPS_FINAL.png',
  'Oamaru'        : 'assets/location_assets/OMRU_CORPS_FINAL.png',
  'Otautau'      : 'assets/location_assets/OTAU_CORPS.png',
  'Palmerston North': 'assets/location_assets/PMRSTN_CORPS_FINAL.png',
  'Queenstown'   : 'assets/location_assets/QTWN_CORPS_FINAL.png',
  'Riverton'     : 'assets/location_assets/RVRTON_CORPS_FINAL.png',
  'Te Anau'      : 'assets/location_assets/TEANAU_CORPS.png',
  'Timaru'       : 'assets/location_assets/TIMARU_CORPS_FINAL.png',
  'Temuka'    : 'assets/location_assets/TMUKA_CORPS.png',
  'Winton'       : 'assets/location_assets/WINTON_CORPS.png',
  'Wanaka'       : 'assets/location_assets/WKAKA_CORPS.png',
};

/// A fallback asset if the locationName isn’t found above.
const String defaultLocationAsset =
    'assets/location_assets/FINAL_WEST_CORPS_LOGO.PNG';
