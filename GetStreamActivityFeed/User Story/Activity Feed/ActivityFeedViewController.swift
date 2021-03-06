//
//  ActivityFeedViewController.swift
//  GetStreamActivityFeed
//
//  Created by Alexey Bukhtin on 11/03/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import GetStream

final class ActivityFeedViewController: FlatFeedViewController<Activity>, BundledStoryboardLoadable {
    static var storyboardName = "ActivityFeed"
    
    var profileBuilder: ProfileBuilder?
    var notificationsPresenter: NotificationsPresenter<Activity>?
    var notificationsSubscriptionId: SubscriptionId?
    
    private lazy var activityRouter: ActivityRouter? = {
        if let profileBuilder = profileBuilder {
            let activityRouter = ActivityRouter(viewController: self, profileBuilder: profileBuilder)
            return activityRouter
        }
        
        return nil
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tabBarItem = UITabBarItem(title: "Home", image: .homeIcon, tag: 0)
        hideBackButtonTitle()
        subscribeForUpdates()
        setupBellButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateBellCounter()
        
        if parent == nil || parent is UINavigationController {
            navigationController?.restoreDefaultNavigationBar(animated: animated)
        }
    }
    
    @IBAction func showEditPost(_ sender: Any) {
        performSegue(show: EditPostViewController.self, sender: nil)
    }
    
    override func dataLoaded(_ error: Error?) {
        super.dataLoaded(error)
        showErrorAlertIfNeeded(error)
    }
    
    override func updateAvatar(in cell: PostHeaderTableViewCell, activity: Activity) {
        cell.updateAvatar(with: activity.actor) { [weak self] _ in
            if let self = self,
                let profileViewCotroller = self.profileBuilder?.profileViewController(user: activity.actor) {
                profileViewCotroller.builder = self.profileBuilder
                self.navigationController?.pushViewController(profileViewCotroller, animated: true)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let activityPresenter = activityPresenter(in: indexPath.section),
            let cellType = activityPresenter.cellType(at: indexPath.row) else {
            return
        }
        
        var showDetail = indexPath.row == 0
        
        if !showDetail, case .actions = cellType {
            showDetail = true
        }
        
        if showDetail {
            performSegue(show: PostDetailTableViewController.self, sender: activityPresenter)
        } else {
            super.tableView(tableView, didSelectRowAt: indexPath)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let editPostnavigationController = segue.destination as? UINavigationController,
            let editPostViewController = editPostnavigationController.viewControllers.first as? EditPostViewController,
            let userFeedId = FeedId.user {
            editPostViewController.presenter = EditPostPresenter(flatFeed: Client.shared.flatFeed(userFeedId),
                                                                 view: editPostViewController)
            return
        }
        
        guard let activityDetailTableViewController = segue.destination as? PostDetailTableViewController,
            let activityPresenter = sender as? ActivityPresenter<Activity> else {
                return
        }
        
        activityDetailTableViewController.activityPresenter = activityPresenter
        activityDetailTableViewController.sections = [.activity, .comments]
    }
}

// MARK: - Bell Button

extension ActivityFeedViewController {
    func setupBellButton() {
        guard let notificationsPresenter = notificationsPresenter else {
            return
        }
        
        let bellButton = BellButton()
        bellButton.addTap { [weak self] _ in self?.tabBarController?.selectTab(with: NotificationsViewController.self) }
        
        notificationsSubscriptionId = notificationsPresenter.subscriptionPresenter.subscribe { [weak bellButton] in
            if let response = try? $0.get() {
                let newCount = response.newActivities.count
                let removedCount = response.deletedActivitiesIds.count
                bellButton?.count += newCount > 0 ? newCount : (removedCount > 0 ? removedCount : 0)
            } else {
                bellButton?.count = 0
            }
        }
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: bellButton)
    }
    
    func updateBellCounter() {
        guard let notificationsViewController = tabBarController?.find(viewControllerType: NotificationsViewController.self),
            let bellButton = navigationItem.leftBarButtonItem?.customView as? BellButton else {
                return
        }
        
        bellButton.count = notificationsViewController.badgeValue
    }
}
