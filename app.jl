using Dash, DashCoreComponents, DashHtmlComponents, CSV, HTTP, UrlDownload, DataFrames, Dates, PlotlyJS;

res = HTTP.get("https://data.humdata.org/hxlproxy/api/data-preview.csv?url=https%3A%2F%2Fraw.githubusercontent.com%2FCSSEGISandData%2FCOVID-19%2Fmaster%2Fcsse_covid_19_data%2Fcsse_covid_19_time_series%2Ftime_series_covid19_confirmed_global.csv&filename=time_series_covid19_confirmed_global.csv");
global covCsv = CSV.File(res.body; delim=",");

app = dash();

function normalizeAllRegions(amounts, data)
    returnValue = [];
    for row in unique(data)
        allval = findall(x->x==row, data);
        all = 0;
        for amount in allval
            all += amounts[amount];
        end;
        push!(returnValue, all);
    end;
    return returnValue;
end;

function normalizeAllCountry(data)
    returnValue = [];
    for row in countries
        allval = findall(x->x[1]==row, data);
        all = 0;
        for amount in allval
            all += data[amount][2];
        end;
        push!(returnValue, (row,all));
    end;
    return returnValue;
end;

function showCountryChart(selectedCountry)
    allCasesArray = [];
    perDayCasesArray = [];
    dateArray = [];
    for row in covCsv
        country = getproperty(row, Symbol("Country/Region"));
        if(country == selectedCountry)
            properties = propertynames(row);
            val = values(row);
            foreach(x -> begin
                    spl = split(string(x), "/");
                    push!(dateArray,DateTime((2000 + parse(Int64, spl[3])),parse(Int64, spl[1]),parse(Int64, spl[2])));
                end, properties[5:length(properties)]);
            foreach(x -> push!(allCasesArray, x), val[5:length(val)]);
            yesterday = val[5];
            foreach(x -> begin 
                    today = x - yesterday;
                    yesterday = x;
                    push!(perDayCasesArray, today);
                end, val[5:length(val)]);
        end;
    end;
    return allCasesArray, perDayCasesArray, dateArray
end;

function countAllData()
    res = HTTP.get("https://data.humdata.org/hxlproxy/api/data-preview.csv?url=https%3A%2F%2Fraw.githubusercontent.com%2FCSSEGISandData%2FCOVID-19%2Fmaster%2Fcsse_covid_19_data%2Fcsse_covid_19_time_series%2Ftime_series_covid19_confirmed_global.csv&filename=time_series_covid19_confirmed_global.csv");
    global covCsv = CSV.File(res.body; delim=",");

    global todayCasesByCountry = [];
    for row in covCsv
        
        country = getproperty(row, Symbol("Country/Region"));
        todayCases = row[length(row)] - row[length(row) - 1];
        tempArr = [("$(country)", todayCases)];
        global todayCasesByCountry = [todayCasesByCountry ; tempArr];
       
    end;
    
    global countries = [];
    for row in covCsv
        country = getproperty(row, Symbol("Country/Region"));
        push!(countries, country);
    end;
    
    countries = unique(countries);
    
    todayCasesByCountryArray = normalizeAllCountry(todayCasesByCountry);
    global todayCasesByCountryArray = sort!(todayCasesByCountryArray, by = x -> x[2]);
    
    global countriesWithoutNew = 0;
    for row in todayCasesByCountryArray
        if(row[2] == 0)
            global countriesWithoutNew += 1;
        end;
    end;
    
    global leastDisease = 0;
    global leastDiseaseCc = "";
    for row in todayCasesByCountryArray
        if(row[2] > 0)
            global leastDisease = row[2];
            global leastDiseaseCc = row[1];
            break;
        end;
    end;
end;

countAllData()

app.layout = html_div() do
    
    html_h1(["COVID-19 DASHBOARD - Julia version"], style=(textAlign="center",)),
    html_div(id = "dataDiv",[
        "Dane pobrano z dnia: ", 
        html_b(id = "liveUpdate","ładowanie aktualnych danych...  "),
        html_a(html_button(id="button","Odśwież dane",n_clicks=0,style=(visibility="hidden",)))],
        style=(textAlign="center",)),
    html_div(id = "basicData",
        [html_div(id = "firstDiv"),
        html_div(id = "secondDiv"),
        html_div(id = "thirdDiv")]),
    html_div([
        dcc_graph(
        id = "top-5",
        ),
        html_div("Wybierz Kraj:", style=(paddingBottom="1%",paddingLeft="5%",)),
        dcc_dropdown(
        id = "dropDown",
        options = [
            (label = i, value = i) for i in  countries
        ],
        value = "Poland",
        style=(width="40%",),
        multi=true
        ),
        dcc_graph(
        id = "lineChart",
        
        ),
        dcc_graph(
        id = "barChart",
        
    )])
end;

callback!(
    app,
    Output("liveUpdate", "children"),
    Input("button", "n_clicks"), 

) do variable;
    
    countAllData()
    timeRightNow = Dates.now()
    timeRightNow = Dates.format(timeRightNow, "dd-mm-yyyy HH:MM:SS")
    return string(timeRightNow, " ");
end;

callback!(
    app,
    Output("dataDiv", "children"),
    Input("button", "n_clicks"), 

) do variable;
    return html_div([
    "Dane pobrano: ", 
    html_b(id = "liveUpdate","ładowanie aktualnych danych...  "),
    html_a(html_button(id="button","Odśwież dane",n_clicks=0,style=(visibility="hidden",)))],
    style=(textAlign="center",))
end;

callback!(
    app,
    Output("basicData", "children"),
    Input("button", "n_clicks"), 

) do variable;
    return html_div([
        html_div(id = "firstDiv"),
        html_div(id = "secondDiv"),
        html_div(id = "thirdDiv")],style=(visibility="hidden",))
end;

callback!(
    app,
    Output("button", "children"),
    Input("liveUpdate", "children"), 

) do variable;
    return html_div([html_button(id="button","Odśwież dane",n_clicks=0,style=(visibility="visible",))])
end;

callback!(
    app,
    Output("firstDiv", "children"),
    Output("secondDiv", "children"),
    Output("thirdDiv", "children"),
    Input("liveUpdate", "children"), 

) do variable;
        return html_div([
        "Odnotowano najwięcej przypadków zakażeń w kraju: ",
        html_b(todayCasesByCountryArray[length(todayCasesByCountryArray)][1]),
        " z liczbą ",
        html_b(todayCasesByCountryArray[length(todayCasesByCountryArray)][2]),
        " przypdaków"] , style=(textAlign="center",visibility="visible",)),
        html_div([
        "Odnotowano najmniej przypadków zakażeń w kraju: ",
        html_b(leastDiseaseCc), 
        " z liczbą ",
        html_b(leastDisease),
        " przypdaków"
        ], style=(textAlign="center",visibility="visible",)),
        html_div([
        "Nie odnotowano nowych przypadków w ",
        html_b(countriesWithoutNew),
        " krajach"], style=(textAlign="center",visibility="visible", paddingBottom="3%",))
end;


callback!(
    app,
    Output("dropDown", "value"),
    Input("liveUpdate", "children"),
    
) do variable;
    return "Poland";
end;

callback!(
    app,
    Output("lineChart", "figure"),
    Output("barChart", "figure"),
    Output("top-5", "figure"),
    Input("dropDown", "value"),
    
) do selectedCountry;
    
    allCases = []
    perDay = []
    labelAllCases = "Wszystkie przypadki dla "
    labelDayCases = "Dobowy przyrost dla "
    if typeof(selectedCountry) != String
        foreach(x -> begin
            chartsForCountry = showCountryChart(x)
            push!(allCases , (x = chartsForCountry[3], y = chartsForCountry[1], type = "line", name = x))
            push!(perDay , (x = chartsForCountry[3], y = chartsForCountry[2], type = "bar", name = x))
            labelAllCases = string(labelAllCases ,  x , ", ")
            labelDayCases = string(labelDayCases ,  x , ", ")
            end, selectedCountry;
        )
        labelAllCases = chop(labelAllCases, tail=2)
        labelDayCases = chop(labelDayCases, tail=2)
    else
        chartsForCountry = showCountryChart(selectedCountry)
        push!(allCases , (x = chartsForCountry[3], y = chartsForCountry[1], type = "line", name = selectedCountry))
        push!(perDay , (x = chartsForCountry[3], y = chartsForCountry[2], type = "bar", name = selectedCountry))
        labelAllCases = string(labelAllCases,selectedCountry)
        labelDayCases = string(labelDayCases,selectedCountry)
    end

    ccArray = [];
    for row in covCsv
    
        country = getproperty(row, Symbol("Country/Region"));
        tempArr = [("$(country)", row[length(row)])];
        ccArray = [ccArray ; tempArr];
    end;

    ccArray = sort!(ccArray, by = x -> x[2], rev = true);
    countriesTop5 = normalizeAllCountry(ccArray);
    countriesTop5 = sort!(countriesTop5, by = x -> x[2], rev = true);

    top5Countries = [];
    top5Values = [];
    for i = 1:5
        push!(top5Countries, countriesTop5[i][1]);
        push!(top5Values, countriesTop5[i][2]);
    end;

   figure = (
            data = allCases,
            layout = (title = labelAllCases,)
        );
      
    figure2 = (
            data = perDay,
            layout = (title = labelDayCases ,barmode="stack")
        
    );
    figure3 = (
            data = [
                (x = top5Countries, y = top5Values, type = "bar", name = "SF"),
            ],
            layout = (title = "Kraje z największą liczbą przypadków zakażeń",)
        
    );
    return figure, figure2, figure3;
end;



run_server(app, "0.0.0.0")
