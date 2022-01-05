import Foundation
import UIKit

@objc class DashboardViewController: UITableViewController {
    @objc var blog: Blog?

    @objc var drafts: Bool = true

    var fetchedResultsController: NSFetchedResultsController<Post>!

    lazy var filterSettings: PostListFilterSettings = {
        return PostListFilterSettings(blog: self.blog!, postType: .post)
    }()

    private(set) var ghostableTableView = IntrinsicTableView()

    override func viewDidLoad() {
        tableView = IntrinsicTableView()
        view.backgroundColor = .systemBackground

        configureGhostableTableView()
        configureTableView()
        createFetchedResultsController()
        sync()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }

    func createFetchedResultsController() {
        // 0 = published, 1 = draft, 2 = scheduled
        filterSettings.setCurrentFilterIndex(drafts ? 1 : 0)

        fetchedResultsController?.delegate = nil
        fetchedResultsController = nil

        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest(), managedObjectContext: managedObjectContext(), sectionNameKeyPath: nil, cacheName: nil)

        fetchedResultsController.delegate = self
    }

    func refresh() {
        do {
            try fetchedResultsController.performFetch()
            tableView.reloadData()
        } catch {
            print("Fetch failed")
        }
    }

    func configureTableView() {
        let postCompactCellNib = UINib(nibName: "PostCompactCell", bundle: Bundle.main)
        tableView.register(postCompactCellNib, forCellReuseIdentifier: "PostCompactCellIdentifier")

        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = CGFloat(300.0)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
    }

    func predicateForFetchRequest() -> NSPredicate {
       var predicates = [NSPredicate]()

       if let blog = blog {
           // Show all original posts without a revision & revision posts.
           let basePredicate = NSPredicate(format: "blog = %@ && revision = nil", blog)
           predicates.append(basePredicate)
       }

        let filterPredicate = filterSettings.currentPostListFilter().predicateForFetchRequest
        predicates.append(filterPredicate)

       let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
       return predicate
    }

    func managedObjectContext() -> NSManagedObjectContext {
        ContextManager.shared.mainContext
    }

    func fetchRequest() -> NSFetchRequest<Post> {
        let fetchRequest = NSFetchRequest<Post>(entityName: String(describing: Post.self))
        fetchRequest.predicate = predicateForFetchRequest()
        fetchRequest.sortDescriptors = sortDescriptorsForFetchRequest()
        fetchRequest.fetchBatchSize = 3
        fetchRequest.fetchLimit = 3
        return fetchRequest
    }

    @objc func sortDescriptorsForFetchRequest() -> [NSSortDescriptor] {
        return filterSettings.currentPostListFilter().sortDescriptors
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PostCompactCellIdentifier", for: indexPath)

        ghostableTableView.isHidden = true

        configureCell(cell, at: indexPath)

        return cell
    }

    fileprivate func postAtIndexPath(_ indexPath: IndexPath) -> Post {
        fetchedResultsController.object(at: indexPath)
    }

    func configureCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
        cell.accessoryType = .none

        let post = postAtIndexPath(indexPath)

        guard let configurablePostView = cell as? ConfigurablePostView else {
                fatalError("Cell does not implement the required protocols")
        }

        configurablePostView.configure(with: post)
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.estimatedRowHeight
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let post = postAtIndexPath(indexPath)

        PostListEditorPresenter.handle(post: post, in: self)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }

    // Ghostable

    func configureGhostableTableView() {
        view.addSubview(ghostableTableView)

        ghostableTableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ghostableTableView.widthAnchor.constraint(equalTo: view.widthAnchor),
            ghostableTableView.heightAnchor.constraint(equalTo: view.heightAnchor),
            ghostableTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ghostableTableView.topAnchor.constraint(equalTo: view.topAnchor)
        ])

        ghostableTableView.backgroundColor = .white
        ghostableTableView.isScrollEnabled = false

        let postCompactCellNib = UINib(nibName: "PostCompactCell", bundle: Bundle.main)
        ghostableTableView.register(postCompactCellNib, forCellReuseIdentifier: "PostCompactCellIdentifier")

        let ghostOptions = GhostOptions(displaysSectionHeader: false, reuseIdentifier: "PostCompactCellIdentifier", rowsPerSection: [3])
        let style = GhostStyle(beatDuration: GhostStyle.Defaults.beatDuration,
                               beatStartColor: .placeholderElement,
                               beatEndColor: .placeholderElementFaded)
        ghostableTableView.removeGhostContent()
        ghostableTableView.displayGhostContent(options: ghostOptions, style: style)

//        print("$$ what?")
    }

    func sync() {
        let filter = filterSettings.currentPostListFilter()
        let author = filterSettings.shouldShowOnlyMyPosts() ? blog!.userID : nil

        let postService = PostService(managedObjectContext: managedObjectContext())

        let options = PostServiceSyncOptions()
        options.statuses = filter.statuses.strings
        options.authorID = author
        options.number = 4
        options.purgesLocalSync = true

        postService.syncPosts(
            ofType: .post,
            with: options,
            for: blog!,
            success: {[weak self] posts in

            }, failure: {[weak self] (error: Error?) -> () in

        })
    }
}

extension DashboardViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()

        if fetchedResultsController.fetchRequest.fetchLimit > 0 && fetchedResultsController.fetchRequest.fetchLimit < fetchedResultsController.fetchedObjects?.count ?? 0 {
            try? fetchedResultsController.performFetch()
            tableView.reloadData()
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch (type) {
        case .insert:
            if let indexPath = newIndexPath {
                tableView.insertRows(at: [indexPath], with: .fade)
            }
            break;
        case .delete:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
            break;
        case .update:
            if let indexPath = indexPath, let cell = tableView.cellForRow(at: indexPath) {
                configureCell(cell, at: indexPath)
            }
            break;
        case .move:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }

            if let newIndexPath = newIndexPath {
                tableView.insertRows(at: [newIndexPath], with: .fade)
            }
            break;
        @unknown default:
            break;
        }
    }

}
