import Foundation
import UIKit

class DashboardViewController: UITableViewController, WPTableViewHandlerDelegate {
    var blog: Blog?

    @objc lazy var tableViewHandler: WPTableViewHandler = {
        let tableViewHandler = WPTableViewHandler(tableView: self.tableView)

        tableViewHandler.cacheRowHeights = false
        tableViewHandler.delegate = self
        tableViewHandler.updateRowAnimation = .none

        return tableViewHandler
    }()

    lazy var filterSettings: PostListFilterSettings = {
        return PostListFilterSettings(blog: self.blog!, postType: .post)
    }()

    override func viewDidLoad() {
        view.backgroundColor = .systemBackground
        filterSettings.setCurrentFilterIndex(0)
        configureTableView()
    }

    func configureTableView() {
        let postCompactCellNib = UINib(nibName: "PostCompactCell", bundle: Bundle.main)
        tableView.register(postCompactCellNib, forCellReuseIdentifier: "PostCompactCellIdentifier")

        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = CGFloat(300.0)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
    }

    override func viewWillAppear(_ animated: Bool) {
        do {
            try tableViewHandler.resultsController.performFetch()
        } catch {
            DDLogError("Error fetching posts after updating the fetch request predicate: \(error)")
        }
    }

    func predicateForFetchRequest() -> NSPredicate {
       var predicates = [NSPredicate]()

       if let blog = blog {
           // Show all original posts without a revision & revision posts.
           let basePredicate = NSPredicate(format: "blog = %@ && revision = nil", blog)
           predicates.append(basePredicate)
       }

       let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
       return predicate
    }

    func managedObjectContext() -> NSManagedObjectContext {
        ContextManager.shared.mainContext
    }

    func fetchRequest() -> NSFetchRequest<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: Post.self))
        fetchRequest.predicate = predicateForFetchRequest()
        fetchRequest.sortDescriptors = sortDescriptorsForFetchRequest()
        fetchRequest.fetchBatchSize = 10
        fetchRequest.fetchLimit = 3
        return fetchRequest
    }

    @objc func sortDescriptorsForFetchRequest() -> [NSSortDescriptor] {
        return filterSettings.currentPostListFilter().sortDescriptors
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let post = postAtIndexPath(indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: "PostCompactCellIdentifier", for: indexPath)

        configureCell(cell, at: indexPath)

        return cell
    }

    fileprivate func postAtIndexPath(_ indexPath: IndexPath) -> Post {
        guard let post = tableViewHandler.resultsController.object(at: indexPath) as? Post else {
            // Retrieving anything other than a post object means we have an App with an invalid
            // state.  Ignoring this error would be counter productive as we have no idea how this
            // can affect the App.  This controlled interruption is intentional.
            //
            // - Diego Rey Mendez, May 18 2016
            //
            fatalError("Expected a post object.")
        }

        return post
    }

    func configureCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
        cell.accessoryType = .none

        let post = postAtIndexPath(indexPath)

        guard let interactivePostView = cell as? InteractivePostView,
            let configurablePostView = cell as? ConfigurablePostView else {
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let post = postAtIndexPath(indexPath)

        PostListEditorPresenter.handle(post: post, in: self)
    }
}
