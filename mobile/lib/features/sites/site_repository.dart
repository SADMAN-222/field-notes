import '../../core/database/database.dart';
import '../../core/database/daos/sites_dao.dart';

class SiteRepository {
  final SitesDao sitesDao;
  
  SiteRepository({required this.sitesDao});

  Stream<List<Site>> watchSites(String customerId) => sitesDao.watchSitesByCustomer(customerId);
  
  Future<void> addSite(Site site) => sitesDao.createSite(site);
  
  Future<void> updateSite(Site site) => sitesDao.updateSite(site);
  
  Future<void> deleteSite(Site site) => sitesDao.deleteSite(site);
}

