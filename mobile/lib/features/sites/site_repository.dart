import 'package:flutter/foundation.dart';
import '../../core/database/database.dart';
import '../../core/database/daos/sites_dao.dart';

class SiteRepository {
  final SitesDao sitesDao;

  SiteRepository({required this.sitesDao});

  Stream<List<Site>> watchSites(String customerId, String userId) =>
      sitesDao.watchSitesByCustomer(customerId, userId);

  Stream<List<Site>> watchAllSites(String userId) =>
      sitesDao.watchAllSites(userId);

  Future<List<Site>> getAllSites(String userId) =>
      sitesDao.getAllSites(userId);

  Future<Site?> getSiteById(String id, String userId) =>
      sitesDao.getSiteById(id, userId);

  Stream<Site?> watchSiteById(String id, String userId) =>
      sitesDao.watchSiteById(id, userId);

  Stream<List<Site>> searchSites(String userId, String query, {String? customerId}) =>
      sitesDao.searchSites(userId, query, customerId: customerId);

  Future<int> getSiteCount(String userId) =>
      sitesDao.getSiteCount(userId);

  Future<void> addSite(Site site, String userId) {
    if (site.userId != userId) {
      throw StateError('Site does not belong to the active account.');
    }
    debugPrint('SiteRepository.addSite: ${site.userId}, ID: ${site.id}, Customer: ${site.customerId}');
    return sitesDao.createSite(site);
  }

  Future<void> updateSite(Site site, String userId) {
    if (site.userId != userId) {
      throw StateError('Site does not belong to the active account.');
    }
    return sitesDao.updateSite(site);
  }

  Future<void> deleteSite(Site site, String userId) {
    if (site.userId != userId) {
      throw StateError('Site does not belong to the active account.');
    }
    return sitesDao.deleteSite(site);
  }
}
