# MONEY VIEW
# --------------------------------------------------------------------------
class MoneyView extends ayla.BaseView

    wrapperId: "money"

    # MAIN METHODS
    # ----------------------------------------------------------------------

    # Init the Money view.
    onReady: =>
        @dataProcessor @data

        @createBalanceChart()

    # Parse and process data coming from the server.
    dataProcessor: (key, data) =>
        if not data?
            data = key
            key = null

        if not @data.balanceCss?
            @data.balanceCss = ko.computed =>
                if @data.recentExpenses?.total > @data.recentIncomes?.total
                    return "negative"
                else
                    return "positive"

    # Create a balance line chart with expenses and incomes.
    createBalanceChart: (months) =>
        months = @data.months()

        labels = _.pluck months, "shortDate"
        labels.reverse()

        expensesData = []
        incomesData = []

        for m in months
            expensesData.unshift m.expenses?.amount or 0
            incomesData.unshift m.incomes?.amount or 0

        # Set expenses dataset.
        dsExpenses = {
            label: "Expenses"
            fillColor: "rgba(240, 65, 36, 0.3)"
            strokeColor: "rgb(240, 65, 36)"
            pointColor: "rgb(240, 65, 36)"
            pointStrokeColor: "rgb(250, 245, 240)"
            data: expensesData
        }

        # Set income dataset.
        dsIncomes = {
            label: "Incomes"
            fillColor: "rgba(67, 172, 106, 0.3)"
            strokeColor: "(67, 172, 106)"
            pointColor: "rgb(67, 172, 106)"
            pointStrokeColor: "rgb(245, 250, 240)"
            data: incomesData
        }

        # Create chart.
        chartData = {labels: labels, datasets: [dsExpenses, dsIncomes]}
        canvas = $("canvas.balance").get(0).getContext "2d"
        chart = new Chart(canvas).Line chartData

        @createTagsChart @data.recentExpenses().tags, dsExpenses
        @createTagsChart @data.recentIncomes().tags, dsIncomes

    # Create a radar chart with most used tags.
    createTagsChart: (data, dataset) =>
        identifier = dataset.label.toLowerCase()

        dataset.data = []
        labels = []
        tags = _.sortBy data, "total"
        tags.reverse()

        i = 0
        while i < 10
            labels.push tags[i].tag
            i++

        labels.sort()

        i = 0
        while i < 10
            obj = _.find tags, {tag: labels[i]}
            dataset.data.push obj.total.toFixed 2
            i++

        # Create chart.
        chartData = {labels: labels, datasets: [dataset]}
        canvas = $("." + identifier + " canvas.tags").get(0).getContext "2d"
        chart = new Chart(canvas).Radar chartData

# BIND VIEW TO WINDOW
# --------------------------------------------------------------------------
window.ayla.currentView = new MoneyView()