import UIKit

class RegistrationNetworkModel: NSObject {
    
    dynamic var createNewUser = false
    dynamic var details:BidDetails!
    var bidder:Bidder?

    var fulfillmentNav:FulfillmentNavigationController!

    func registerSignal() -> RACSignal {

        return self.createOrUpdateUser().then {
            self.updateProviderIfNewUser()

        }.then {
            self.addCardToUser()

        }.then {
            self.checkForBidderOnAuction(self.fulfillmentNav.auctionID)

        }.then {
            self.bidder == nil ? self.registerToAuction() : RACSignal.empty()

        }.then {
            self.generateAPIN()

        }.then {
            self.getMyPaddleNumber()
        }
    }

    func provider() -> ReactiveMoyaProvider<ArtsyAPI>  {
        if let provider = fulfillmentNav.loggedInProvider {
            return provider
        }
        return Provider.sharedProvider
    }

    func checkForBidderOnAuction(auctionID: String) -> RACSignal {
        let endpoint: ArtsyAPI = ArtsyAPI.MyBiddersForAuction(auctionID: auctionID)
        let request = provider().request(endpoint, method: .GET, parameters:endpoint.defaultParameters).filterSuccessfulStatusCodes().mapJSON().mapToObjectArray(Bidder.self)

        return request.doNext { [weak self] (bidders) -> Void in
            let bidders = bidders as [Bidder]
            self?.bidder = bidders.first

            }.doError({ [weak self] (error) -> Void in
                println("error, had issues with getting user bidders ")
                return
            })
    }


    func createOrUpdateUser() -> RACSignal {
        let newUser = details.newUser
        if createNewUser {
            
            let endpoint: ArtsyAPI = ArtsyAPI.CreateUser(email: newUser.email!, password: newUser.password!, phone: newUser.phoneNumber!, postCode: newUser.zipCode!)
            return Provider.sharedProvider.request(endpoint, method: .POST, parameters: endpoint.defaultParameters).filterSuccessfulStatusCodes().mapJSON().doError() { (error) -> Void in
                println("Error creating user: \(error.localizedDescription)")
            }
            
        } else {
            let endpoint: ArtsyAPI = ArtsyAPI.UpdateMe(email: newUser.email!, phone: newUser.phoneNumber!, postCode: newUser.zipCode!)

            return provider().request(endpoint, method: .PUT, parameters: endpoint.defaultParameters).filterSuccessfulStatusCodes().mapJSON().doError() { (error) -> Void in
                println("Error updating user in: \(error.localizedDescription)")
            }
        }
    }

    func addCardToUser() -> RACSignal {
        let endpoint: ArtsyAPI = ArtsyAPI.RegisterCard(balancedToken: details.newUser.creditCardToken!)

        return provider().request(endpoint, method: .POST, parameters: endpoint.defaultParameters).filterSuccessfulStatusCodes().doError() { (error) -> Void in
            println("Error adding card: \(error.localizedDescription)")
        }
    }

    func registerToAuction() -> RACSignal {
        let endpoint: ArtsyAPI = ArtsyAPI.RegisterToBid(auctionID: fulfillmentNav.auctionID)
        return provider().request(endpoint, method: .POST, parameters: endpoint.defaultParameters).filterSuccessfulStatusCodes().mapJSON().mapToObject(Bidder.self).doNext({ [weak self](bidder) -> Void in

            self?.fulfillmentNav.bidDetails.bidderID = (bidder as Bidder).id
            return

        }).doError() { (error) -> Void in
            println("Error registering for auction: \(error.localizedDescription)")
        }
    }

    func generateAPIN() -> RACSignal {
        let endpoint: ArtsyAPI = ArtsyAPI.CreatePINForBidder(bidderNumber: fulfillmentNav.bidDetails.bidderID!)

        return provider().request(endpoint, method: .POST, parameters: endpoint.defaultParameters).filterSuccessfulStatusCodes().mapJSON().doNext({ [weak self](json) -> Void in
            
            if let pin = json["pin"] as? String {
                self?.fulfillmentNav.bidDetails.bidderPIN =  pin
            }
                
        }).doError() { (error) -> Void in
            println("Error registering PIN for auction: \(error.localizedDescription)")
        }
    }

    func getMyPaddleNumber() -> RACSignal {
        let endpoint: ArtsyAPI = ArtsyAPI.Me
        return provider().request(endpoint, method: .GET, parameters: endpoint.defaultParameters).filterSuccessfulStatusCodes().mapJSON().mapToObject(User.self).doNext({ [weak self](user) -> Void in

            self?.fulfillmentNav.bidDetails.bidderNumber =  (user as User).paddleNumber
            return

        }).doError() { (error) -> Void in
            println("Error grabbing paddle number for auction: \(error.localizedDescription)")
        }
    }


    func updateProviderIfNewUser() -> RACSignal {
        if self.createNewUser {

            let endpoint: ArtsyAPI = ArtsyAPI.XAuth(email: details.newUser.email!, password: details.newUser.password!)

            return provider().request(endpoint, method:.GET, parameters: endpoint.defaultParameters).filterSuccessfulStatusCodes().mapJSON().doNext({ [weak self] (accessTokenDict) -> Void in

                if let accessToken = accessTokenDict["access_token"] as? String {
                    self?.fulfillmentNav.xAccessToken = accessToken
                }

            }).doError() { (error) -> Void in
                println("Error logging in: \(error.localizedDescription)")
            }

        } else {
            return RACSignal.empty()
        }
    }
}