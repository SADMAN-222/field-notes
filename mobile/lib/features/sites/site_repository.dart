import '../../core/database/database.dart';
import '../../core/database/daos/sites_dao.dart';

class SiteRepository {
  final SitesDao sitesDao;

  SiteRepository({required this.sitesDao});

  Stream<List<Site>> watchSites(String customerId) =>
      sitesDao.watchSitesByCustomer(customerId);

  Stream<List<Site>> watchAllSites(String userId) =>
      sitesDao.watchAllSites(userId);

  Future<List<Site>> getAllSites(String userId) =>
      sitesDao.getAllSites(userId);

  Future<Site?> getSiteById(String id) =>
      sitesDao.getSiteById(id);

  Stream<Site?> watchSiteById(String id) =>
      sitesDao.watchSiteById(id);

  Stream<List<Site>> searchSites(String userId, String query, {String? customerId}) =>
      sitesDao.searchSites(userId, query, customerId: customerId);

  Future<int> getSiteCount(String userId) =>
      sitesDao.getSiteCount(userId);

  Future<void> addSite(Site site) =>
      sitesDao.createSite(site);

  Future<void> updateSite(Site site) =>
      sitesDao.updateSite(site);

  Future<void> deleteSite(Site site) =>
      sitesDao.deleteSite(site);
}
